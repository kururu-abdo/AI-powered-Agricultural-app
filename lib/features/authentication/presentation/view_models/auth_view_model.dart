import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/auth_validation.dart';
import '../../domain/entities/auth_failure.dart';

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, void>(
  AuthViewModel.new,
);

/// Command state only. The Firebase session stream alone controls navigation.
class AuthViewModel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required String email,
    required String password,
    required bool signingUp,
  }) async {
    if (state.isLoading) return;
    final validation = AuthValidation.email(email) ??
        AuthValidation.password(password, signingUp: signingUp);
    if (validation != null) {
      state = AsyncError(AuthFailure(validation), StackTrace.current);
      return;
    }
    final repository = ref.read(authRepositoryProvider);
    await _execute(() => signingUp
        ? repository.signUp(email: email.trim(), password: password)
        : repository.signIn(email: email.trim(), password: password));
  }

  Future<void> signOut() async {
    if (state.isLoading) return;
    final repository = ref.read(authRepositoryProvider);
    await _execute(repository.signOut);
  }

  Future<void> sendPasswordReset(String email) async {
    if (state.isLoading) return;
    final message = AuthValidation.email(email);
    if (message != null) {
      state = AsyncError(AuthFailure(message), StackTrace.current);
      return;
    }
    await _execute(() => ref.read(authRepositoryProvider)
        .sendPasswordReset(email.trim()));
  }

  Future<void> sendVerification() async {
    if (state.isLoading) return;
    await _execute(ref.read(authRepositoryProvider).sendVerification);
  }

  Future<void> refreshVerification() async {
    if (state.isLoading) return;
    await _execute(() async {
      final verified = await ref.read(authRepositoryProvider).refreshVerification();
      if (!verified) {
        throw const AuthFailure('Email is not verified yet. Open the email link first.');
      }
    });
  }

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<void> _execute(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      if (ref.mounted) state = const AsyncData(null);
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncError(
          error is AuthFailure
              ? error
              : const AuthFailure('Something went wrong. Please try again.'),
          stack,
        );
      }
    }
  }
}
