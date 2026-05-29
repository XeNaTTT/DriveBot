import 'dart:async';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_settings.dart';

final class GuestAuthRepository implements AuthRepository {
  GuestAuthRepository({AppUser? initialUser})
      : _currentUser = initialUser,
        _settings = UserSettings(userId: initialUser?.id ?? 'guest');

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  UserSettings _settings;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  UserSettings get currentSettings => _settings;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<AppUser> continueAsGuest() async {
    const user = AppUser.guest();
    _setUser(user);
    return user;
  }

  @override
  Future<void> ensureProfileAndSettings(AppUser user) async {
    _settings = _settings.copyWith(userId: user.id);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async =>
      continueAsGuest();

  @override
  Future<void> signOut() async {
    _settings = const UserSettings.guest();
    _setUser(null);
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    _settings = settings;
    return _settings;
  }

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
