/// Authentication identity, not farm membership or authorization.
class AppUser {
  const AppUser({required this.id, this.email});
  final String id;
  final String? email;
}
