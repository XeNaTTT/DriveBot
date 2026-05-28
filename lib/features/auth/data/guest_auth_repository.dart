import 'dart:async';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

final class GuestAuthRepository implements AuthRepository {
  GuestAuthRepository({AppUser? initialUser}) : _currentUser = initialUser;

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
  Future<void> ensureProfileAndSettings(AppUser user) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async =>
      continueAsGuest();

  @override
  Future<void> signOut() async => _setUser(null);

  @override
  Future<AppUser> signUpWithEmailPassword({
    required String email,
    required String password,
  }) =>
      continueAsGuest();

  Future<void> dispose() => _controller.close();

  void _setUser(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }
}
