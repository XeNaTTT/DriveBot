import 'dart:async';

import 'package:driveassistant_ar/core/config/supabase_config.dart';
import 'package:driveassistant_ar/features/auth/application/auth_controller.dart';
import 'package:driveassistant_ar/features/auth/domain/app_user.dart';
import 'package:driveassistant_ar/features/auth/domain/auth_repository.dart';
import 'package:driveassistant_ar/features/auth/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing Supabase config starts guest mode', () {
    expect(SupabaseConfig.isConfigured, isFalse);
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: SupabaseConfig.isConfigured,
    );

    expect(controller.status, AuthStatus.guest);
    expect(controller.user?.isGuest, isTrue);
    controller.dispose();
  });

  test('auth controller guest state', () async {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );

    await controller.continueAsGuest();

    expect(controller.status, AuthStatus.guest);
    expect(controller.user, isNotNull);
    expect(controller.user!.isGuest, isTrue);
    controller.dispose();
  });

  test('auth controller logged-out state', () {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );

    expect(controller.status, AuthStatus.loggedOut);
    expect(controller.user, isNull);
    controller.dispose();
  });

  test('auth controller logged-in state with fake repository', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(
      repository: repository,
      isSupabaseConfigured: true,
    );

    await controller.signIn(email: 'person@example.com', password: 'secret');

    expect(controller.status, AuthStatus.loggedIn);
    expect(controller.user?.email, 'person@example.com');
    expect(repository.didUpsertProfile, isTrue);
    controller.dispose();
  });

  test('sign out returns safely', () async {
    final controller = AuthController(
      repository: _FakeAuthRepository(
        initialUser: const AppUser.authenticated(
          id: 'user-1',
          email: 'person@example.com',
        ),
      ),
      isSupabaseConfigured: true,
    );

    await controller.signOut();

    expect(controller.status, AuthStatus.loggedOut);
    expect(controller.user, isNull);
    controller.dispose();
  });

  test('profile/settings upsert failure does not crash', () async {
    final controller = AuthController(
      repository: _FakeAuthRepository(throwOnUpsert: true),
      isSupabaseConfigured: true,
    );

    await controller.signUp(email: 'person@example.com', password: 'secret');

    expect(controller.status, AuthStatus.loggedIn);
    expect(controller.errorMessage, isNull);
    expect(
        controller.profileWarning, 'Netzwerkfehler. Bitte versuche es erneut.');
    controller.dispose();
  });

  test('debug setting toggle is saved through repository', () async {
    final repository = _FakeAuthRepository(
      initialUser: const AppUser.authenticated(
        id: 'user-1',
        email: 'person@example.com',
      ),
    );
    final controller = AuthController(
      repository: repository,
      isSupabaseConfigured: true,
    );

    await controller.setShowDebugSourceLabels(true);

    expect(controller.settings.showDebugSourceLabels, isTrue);
    expect(repository.updatedSettings?.showDebugSourceLabels, isTrue);
    controller.dispose();
  });
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.initialUser, this.throwOnUpsert = false});

  final AppUser? initialUser;
  final bool throwOnUpsert;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  UserSettings _settings = const UserSettings.guest();
  bool didUpsertProfile = false;
  UserSettings? updatedSettings;

  @override
  AppUser? get currentUser => _currentUser ?? initialUser;

  @override
  UserSettings get currentSettings => _settings;
  @override
  Future<AppUser> continueAsGuest() async {
    const user = AppUser.guest();
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<void> ensureProfileAndSettings(AppUser user) async {
    didUpsertProfile = true;
    if (throwOnUpsert) {
      throw StateError('upsert failed');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    updatedSettings = settings;
    _settings = settings;
    return _settings;
  }

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _currentUser = AppUser.authenticated(id: 'user-1', email: email);
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AppUser> signUpWithEmailPassword({
    required String email,
    required String password,
  }) =>
      signInWithEmailPassword(email: email, password: password);
}
