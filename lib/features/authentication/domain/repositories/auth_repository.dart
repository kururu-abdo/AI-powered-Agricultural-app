import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> watchSession();
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
}
