class AppUser {
  const AppUser({required this.id, this.email, this.isGuest = false});

  const AppUser.guest()
      : id = 'guest',
        email = null,
        isGuest = true;

  final String id;
  final String? email;
  final bool isGuest;
}
