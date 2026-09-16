import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// This adapter is the data source and repository for this small increment.
/// Split out a data source when another data operation actually needs reuse.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> watchSession() => _auth.authStateChanges().map(
        (user) => user == null ? null : AppUser(id: user.uid, email: user.email),
      );

  @override
  Future<void> signIn({required String email, required String password}) =>
      _translate(() async {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      });

  @override
  Future<void> signUp({required String email, required String password}) =>
      _translate(() async {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      });

  @override
  Future<void> signOut() => _translate(_auth.signOut);

  Future<void> _translate(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  static String messageForCode(String code) => switch (code) {
        'invalid-email' => 'Enter a valid email address.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Unable to sign in. Check your email and password.',
        'email-already-in-use' =>
          'Unable to create this account. Try signing in instead.',
        'weak-password' || 'password-does-not-meet-requirements' =>
          'Choose a stronger password that meets the account policy.',
        'network-request-failed' =>
          'Could not reach authentication. Check your connection and retry.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'user-disabled' => 'This account is unavailable. Contact support.',
        'operation-not-allowed' => 'Email sign-in is not enabled for this app.',
        _ => 'Authentication failed. Please try again.',
      };
}
