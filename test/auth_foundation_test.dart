import 'dart:async';

import 'package:driveassistant_ar/core/config/supabase_config.dart';
import 'package:driveassistant_ar/features/auth/application/auth_controller.dart';
import 'package:driveassistant_ar/features/auth/domain/app_user.dart';
import 'package:driveassistant_ar/features/auth/domain/auth_repository.dart';
import 'package:driveassistant_ar/features/auth/domain/user_settings.dart';
import 'package:driveassistant_ar/features/auth/presentation/auth_gate.dart';
import 'package:driveassistant_ar/features/auth/presentation/login_screen.dart';
import 'package:driveassistant_ar/features/auth/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing Supabase config starts guest mode', () async {
    const config = SupabaseConfig(url: '', anonKey: '');
    expect(config.canInitialize, isFalse);

    final controller = AuthController(
      repository: _FakeAuthRepository(currentUser: const AppUser.guest()),
      isSupabaseConfigured: config.canInitialize,
    );
    addTearDown(controller.dispose);

    await pumpEventQueue();
    expect(controller.status, AuthStatus.guest);
    expect(controller.user?.isGuest, isTrue);
  });

  testWidgets('login screen renders German labels', (tester) async {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(controller: controller)),
    );

    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('Konto erstellen'), findsOneWidget);
    expect(find.text('E-Mail'), findsOneWidget);
    expect(find.text('Passwort'), findsOneWidget);
    expect(find.text('Passwort vergessen?'), findsOneWidget);
    expect(find.text('Ohne Konto fortfahren'), findsOneWidget);
    expect(find.text('Gastmodus'), findsOneWidget);
    expect(find.text('Nutzerkonto'), findsOneWidget);
    expect(find.text('Nicht angemeldet'), findsOneWidget);
  });

  testWidgets('continue as guest works', (tester) async {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          controller: controller,
          builder: (context, controller) => const Text('HUD'),
        ),
      ),
    );

    expect(find.text('Ohne Konto fortfahren'), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth-continue-guest-button')));
    await tester.pumpAndSettle();

    expect(controller.status, AuthStatus.guest);
    expect(find.text('HUD'), findsOneWidget);
  });

  test('auth controller guest state', () async {
    final controller = AuthController(
      repository: _FakeAuthRepository(currentUser: const AppUser.guest()),
      isSupabaseConfigured: false,
    );
    addTearDown(controller.dispose);

    await pumpEventQueue();
    expect(controller.status, AuthStatus.guest);
  });

  test('auth controller logged-out state', () {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );
    addTearDown(controller.dispose);

    expect(controller.status, AuthStatus.loggedOut);
  });

  test('auth controller logged-in state with fake repository', () {
    final controller = AuthController(
      repository: _FakeAuthRepository(
        currentUser: const AppUser.authenticated(
          id: 'user-1',
          email: 'fahrer@example.test',
        ),
      ),
      isSupabaseConfigured: true,
    );
    addTearDown(controller.dispose);

    expect(controller.status, AuthStatus.loggedIn);
    expect(controller.user?.email, 'fahrer@example.test');
  });

  testWidgets('profile screen renders guest state', (tester) async {
    final controller = AuthController(
      repository: _FakeAuthRepository(currentUser: const AppUser.guest()),
      isSupabaseConfigured: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(controller: controller)),
    );

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Nutzerkonto'), findsOneWidget);
    expect(find.text('Gastmodus'), findsOneWidget);
    expect(find.text('Zurück zur App'), findsOneWidget);
    expect(find.text('Abmelden'), findsNothing);
    expect(find.text('Passwort zurücksetzen'), findsNothing);
  });

  test('sign out returns safely', () async {
    final repository = _FakeAuthRepository(
      currentUser: const AppUser.authenticated(
        id: 'user-1',
        email: 'fahrer@example.test',
      ),
    );
    final controller = AuthController(
      repository: repository,
      isSupabaseConfigured: true,
    );
    addTearDown(controller.dispose);

    await controller.signOut();

    expect(repository.signOutCount, 1);
    expect(controller.status, AuthStatus.loggedOut);
  });
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.currentUser});

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  @override
  AppUser? currentUser;
  UserSettings _settings = const UserSettings.guest();
  int signOutCount = 0;

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
  Future<void> ensureProfileAndSettings(AppUser user) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    _settings = settings;
    return _settings;
  }

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = AppUser.authenticated(id: 'user-1', email: email);
    _setUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    _setUser(null);
  }

  @override
  Future<AppUser> signUpWithEmailPassword({
    required String email,
    required String password,
  }) => signInWithEmailPassword(email: email, password: password);

  void _setUser(AppUser? user) {
    currentUser = user;
    _controller.add(user);
  }
}
