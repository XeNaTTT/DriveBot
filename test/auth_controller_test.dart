import 'dart:async';

import 'package:driveassistant_ar/features/auth/application/auth_controller.dart';
import 'package:driveassistant_ar/features/auth/data/guest_auth_repository.dart';
import 'package:driveassistant_ar/features/auth/domain/app_user.dart';
import 'package:driveassistant_ar/features/auth/domain/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing Supabase config starts guest mode', () {
    final controller = AuthController(const GuestAuthRepository());

    expect(controller.state.status, AuthStatus.guest);
    expect(controller.state.message,
        'Supabase ist nicht konfiguriert. Die App läuft im Gastmodus.');

    controller.dispose();
  });

  test('auth controller guest state', () {
    final controller = AuthController(_FakeAuthRepository());

    controller.continueAsGuest();

    expect(controller.state.status, AuthStatus.guest);
    expect(controller.state.canUseHud, isTrue);

    controller.dispose();
  });

  test('auth controller logged-out state', () {
    final controller = AuthController(_FakeAuthRepository());

    expect(controller.state.status, AuthStatus.loggedOut);
    expect(controller.state.canUseHud, isFalse);

    controller.dispose();
  });

  test('auth controller logged-in state using fake repository', () async {
    final controller = AuthController(_FakeAuthRepository());

    await controller.signIn(email: 'test@example.com', password: 'secret');

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.email, 'test@example.com');

    controller.dispose();
  });

  test('sign out returns to logged-out choice', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(repository);

    await controller.signIn(email: 'test@example.com', password: 'secret');
    await controller.signOut();

    expect(controller.state.status, AuthStatus.loggedOut);

    controller.dispose();
  });
}

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  @override
  bool get isConfigured => true;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    final user = AppUser(id: 'user-1', email: email);
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AppUser> signUp({required String email, required String password}) =>
      signIn(email: email, password: password);
}
