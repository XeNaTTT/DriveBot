import 'dart:async';

import 'package:driveassistant_ar/app/app.dart';
import 'package:driveassistant_ar/features/auth/application/auth_controller.dart';
import 'package:driveassistant_ar/features/auth/domain/app_user.dart';
import 'package:driveassistant_ar/features/auth/domain/auth_repository.dart';
import 'package:driveassistant_ar/features/auth/presentation/auth_gate.dart';
import 'package:driveassistant_ar/features/auth/presentation/login_screen.dart';
import 'package:driveassistant_ar/features/auth/presentation/profile_screen.dart';
import 'package:driveassistant_ar/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen renders German labels', (tester) async {
    final controller = AuthController(_FakeAuthRepository());

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: LoginScreen(controller: controller),
    ));

    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('Konto erstellen'), findsOneWidget);
    expect(find.text('E-Mail'), findsOneWidget);
    expect(find.text('Passwort'), findsOneWidget);
    expect(find.text('Passwort vergessen?'), findsOneWidget);
    expect(find.text('Ohne Konto fortfahren'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('continue as guest works', (tester) async {
    final controller = AuthController(_FakeAuthRepository());

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AuthGate(
        controller: controller,
        child: const Scaffold(body: Text('HUD')),
      ),
    ));
    await tester.tap(find.byKey(const Key('continue-as-guest-button')));
    await tester.pumpAndSettle();

    expect(find.text('HUD'), findsOneWidget);
    expect(find.text('Gastmodus'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('profile screen renders guest state', (tester) async {
    final controller = AuthController(_FakeAuthRepository())..continueAsGuest();

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: ProfileScreen(controller: controller),
    ));

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Nutzerkonto'), findsOneWidget);
    expect(find.text('Nicht angemeldet'), findsOneWidget);
    expect(find.text('Gastmodus'), findsOneWidget);
    expect(find.text('Zurück zur App'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('app does not crash when Supabase is unavailable',
      (tester) async {
    await tester.pumpWidget(const DriveAssistantApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('hud-root')), findsOneWidget);
    expect(find.text('Gastmodus'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();

  @override
  bool get isConfigured => true;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async => _controller.add(null);

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    final user = AppUser(id: 'user-1', email: email);
    _controller.add(user);
    return user;
  }

  @override
  Future<AppUser> signUp({required String email, required String password}) =>
      signIn(email: email, password: password);
}
