import 'dart:async';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class GuestAuthRepository implements AuthRepository {
  GuestAuthRepository({bool startAsGuest = true}) {
    _currentUser = startAsGuest ? const AppUser.guest() : null;
    _controller.add(_currentUser);
  }

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<AppUser> continueAsGuest() async {
    const user = AppUser.guest();
    _setUser(user);
    return user;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      continueAsGuest();

  @override
  Future<AppUser> signUp({required String email, required String password}) =>
      continueAsGuest();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async => _setUser(null);

  void _setUser(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }
}
