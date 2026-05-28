/// UI-agnostic authenticated or guest user representation.
final class AppUser {
  const AppUser._(
      {required this.id, required this.email, required this.isGuest});

  const AppUser.authenticated({required String id, String? email})
      : this._(id: id, email: email, isGuest: false);

  const AppUser.guest() : this._(id: 'guest', email: null, isGuest: true);

  final String id;
  final String? email;
  final bool isGuest;

  bool get isAuthenticated => !isGuest;
}
