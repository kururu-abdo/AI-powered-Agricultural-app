import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core_database/firebase_providers.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'domain/entities/app_user.dart';
import 'domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

final authSessionProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});
