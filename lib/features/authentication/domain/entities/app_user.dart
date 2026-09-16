/// Identity only; farm permissions are checked independently on the server.
class AppUser {
  const AppUser({required this.id, this.email, this.emailVerified = false});
  final String id;
  final String? email;
  final bool emailVerified;
}
