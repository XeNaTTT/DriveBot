import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    if (!_repository.isConfigured) {
      _state = AuthState.guest(
        message: 'Supabase ist nicht konfiguriert. Die App läuft im Gastmodus.',
      );
      return;
    }

    final currentUser = _repository.currentUser;
    _state = currentUser == null
        ? const AuthState.loggedOut()
        : AuthState.authenticated(currentUser);
    _subscription = _repository.authStateChanges.listen((user) {
      _state = user == null
          ? const AuthState.loggedOut()
          : AuthState.authenticated(user);
      notifyListeners();
    });
  }

  final AuthRepository _repository;
  StreamSubscription<AppUser?>? _subscription;
  AuthState _state = const AuthState.loading();

  AuthState get state => _state;

  void continueAsGuest() {
    _state = const AuthState.guest();
    notifyListeners();
  }

  void returnToLogin() {
    if (!_repository.isConfigured) return;
    _state = const AuthState.loggedOut();
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    _setLoading();
    try {
      final user = await _repository.signIn(email: email, password: password);
      _state = AuthState.authenticated(user);
    } on Object {
      _state = const AuthState.loggedOut(error: 'Anmeldung fehlgeschlagen.');
    }
    notifyListeners();
  }

  Future<void> signUp({required String email, required String password}) async {
    _setLoading();
    try {
      final user = await _repository.signUp(email: email, password: password);
      _state = AuthState.authenticated(user);
    } on Object {
      _state = const AuthState.loggedOut(
          error: 'Konto konnte nicht erstellt werden.');
    }
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
      _state = const AuthState.loggedOut(
        message: 'Passwort zurücksetzen: Bitte prüfe dein E-Mail-Postfach.',
      );
    } on Object {
      _state = const AuthState.loggedOut(
        error: 'Netzwerkfehler. Bitte versuche es erneut.',
      );
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _state = _repository.isConfigured
        ? const AuthState.loggedOut()
        : const AuthState.guest();
    notifyListeners();
  }

  void _setLoading() {
    _state = const AuthState.loading();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

enum AuthStatus { loading, loggedOut, authenticated, guest }

class AuthState {
  const AuthState._({
    required this.status,
    this.user,
    this.error,
    this.message,
  });

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.loggedOut({String? error, String? message})
      : this._(status: AuthStatus.loggedOut, error: error, message: message);

  const AuthState.authenticated(AppUser user)
      : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.guest({String? message})
      : this._(status: AuthStatus.guest, message: message);

  final AuthStatus status;
  final AppUser? user;
  final String? error;
  final String? message;

  bool get canUseHud =>
      status == AuthStatus.authenticated || status == AuthStatus.guest;
  bool get isGuest => status == AuthStatus.guest;
}
