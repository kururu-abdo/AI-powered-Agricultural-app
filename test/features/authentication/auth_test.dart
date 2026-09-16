import 'dart:async';

import 'package:agri_intelligence/features/authentication/auth_providers.dart';
import 'package:agri_intelligence/features/authentication/data/repositories/firebase_auth_repository.dart';
import 'package:agri_intelligence/features/authentication/domain/auth_validation.dart';
import 'package:agri_intelligence/features/authentication/domain/entities/app_user.dart';
import 'package:agri_intelligence/features/authentication/domain/entities/auth_failure.dart';
import 'package:agri_intelligence/features/authentication/domain/repositories/auth_repository.dart';
import 'package:agri_intelligence/features/authentication/presentation/view_models/auth_view_model.dart';
import 'package:agri_intelligence/features/authentication/presentation/views/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  final events = StreamController<AppUser?>.broadcast();
  Completer<void>? pending;
  Object? failure;
  int signInCalls = 0;
  String? receivedEmail;
  String? receivedPassword;

  @override
  Stream<AppUser?> watchSession() async* {
    yield null;
    yield* events.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    receivedEmail = email;
    receivedPassword = password;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signUp({required String email, required String password}) =>
      signIn(email: email, password: password);

  @override
  Future<void> signOut() async => events.add(null);
}

void main() {
  test('signup validates strength but login allows legacy passwords', () {
    expect(AuthValidation.email(' farmer@example.com '), isNull);
    expect(AuthValidation.email('farmer example.com'), isNotNull);
    expect(AuthValidation.password('short', signingUp: true), isNotNull);
    expect(AuthValidation.password('short', signingUp: false), isNull);
  });

  test('duplicate submissions are blocked; passwords remain unchanged', () async {
    final fake = FakeAuthRepository()..pending = Completer<void>();
    addTearDown(fake.events.close);
    final container = ProviderContainer.test(overrides: [
      authRepositoryProvider.overrideWithValue(fake),
    ]);
    await container.read(authViewModelProvider.future);
    final vm = container.read(authViewModelProvider.notifier);
    final first = vm.submit(email: ' farmer@example.com ',
        password: ' secret  ', signingUp: false);
    await vm.submit(email: 'other@example.com', password: 'other', signingUp: false);
    expect(fake.signInCalls, 1);
    expect(fake.receivedEmail, 'farmer@example.com');
    expect(fake.receivedPassword, ' secret  ');
    expect(container.read(authViewModelProvider).isLoading, isTrue);
    fake.pending!.complete();
    await first;
    expect(container.read(authViewModelProvider).hasError, isFalse);
  });

  test('invalid input never calls repository; errors allow retry', () async {
    final fake = FakeAuthRepository();
    addTearDown(fake.events.close);
    final container = ProviderContainer.test(overrides: [
      authRepositoryProvider.overrideWithValue(fake),
    ]);
    await container.read(authViewModelProvider.future);
    final vm = container.read(authViewModelProvider.notifier);
    await vm.submit(email: 'bad', password: '', signingUp: false);
    expect(fake.signInCalls, 0);
    fake.failure = const AuthFailure('Check connection.');
    await vm.submit(email: 'farmer@example.com', password: 'secret', signingUp: false);
    expect(container.read(authViewModelProvider).error, isA<AuthFailure>());
    fake.failure = null;
    await vm.submit(email: 'farmer@example.com', password: 'secret', signingUp: false);
    expect(container.read(authViewModelProvider).hasError, isFalse);
  });

  test('credential errors do not distinguish missing users', () {
    expect(FirebaseAuthRepository.messageForCode('user-not-found'),
        FirebaseAuthRepository.messageForCode('wrong-password'));
    expect(FirebaseAuthRepository.messageForCode('internal-secret-detail'),
        'Authentication failed. Please try again.');
  });

  testWidgets('session stream gates home and logout returns to login', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Your farm. In the field.'), findsNothing);
    fake.events.add(const AppUser(id: 'farmer-1', email: 'farmer@example.com'));
    await tester.pumpAndSettle();
    expect(find.text('Your farm. In the field.'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Your farm. In the field.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await fake.events.close();
  });
}
