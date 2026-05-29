import 'dart:async';

import 'package:driveassistant_ar/features/auth/application/auth_controller.dart';
import 'package:driveassistant_ar/features/auth/domain/app_user.dart';
import 'package:driveassistant_ar/features/auth/domain/auth_repository.dart';
import 'package:driveassistant_ar/features/auth/domain/user_settings.dart';
import 'package:driveassistant_ar/features/auth/presentation/auth_gate.dart';
import 'package:driveassistant_ar/features/auth/presentation/login_screen.dart';
import 'package:driveassistant_ar/features/auth/presentation/profile_screen.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen renders German labels', (tester) async {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: LoginScreen(controller: controller),
    ));

    expect(find.text('Nutzerkonto'), findsOneWidget);
    expect(find.text('E-Mail'), findsOneWidget);
    expect(find.text('Passwort'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('Konto erstellen'), findsOneWidget);
    expect(find.text('Passwort vergessen?'), findsOneWidget);
    expect(find.text('Ohne Konto fortfahren'), findsOneWidget);
    expect(find.text('Gastmodus'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('continue as guest opens the HUD/main app', (tester) async {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AuthGate(
        controller: controller,
        builder: (_, controller) => Scaffold(
          body: Stack(
            children: [
              const Text('HUD'),
              AccountEntryButton(controller: controller),
            ],
          ),
        ),
      ),
    ));

    expect(find.text('Anmelden'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-continue-guest-button')));
    await tester.pumpAndSettle();

    expect(find.text('HUD'), findsOneWidget);
    expect(find.byKey(const Key('account-entry-button')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('profile screen renders guest state', (tester) async {
    final controller = AuthController(
      repository: _FakeAuthRepository(),
      isSupabaseConfigured: true,
    );
    await controller.continueAsGuest();

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: ProfileScreen(controller: controller),
    ));

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Nutzerkonto'), findsOneWidget);
    expect(find.text('Gastmodus'), findsOneWidget);
    expect(find.text('Zurück zur App'), findsOneWidget);
    expect(find.text('Abmelden'), findsNothing);
    controller.dispose();
  });
}

final class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  UserSettings _settings = const UserSettings.guest();

  @override
  AppUser? get currentUser => _currentUser;

  @override
  UserSettings get currentSettings => _settings;
  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<AppUser> continueAsGuest() async {
    const user = AppUser.guest();
    _currentUser = user;
    _controller.add(user);
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
