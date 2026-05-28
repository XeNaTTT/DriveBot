import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

enum AuthStatus { guest, loggedOut, loggedIn }

final class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required bool isSupabaseConfigured,
  })  : _repository = repository,
        _isSupabaseConfigured = isSupabaseConfigured,
        _status = isSupabaseConfigured
            ? (repository.currentUser == null
                ? AuthStatus.loggedOut
                : AuthStatus.loggedIn)
            : AuthStatus.guest,
        _user = isSupabaseConfigured
            ? repository.currentUser
            : (repository.currentUser ?? const AppUser.guest()) {
    _subscription = _repository.authStateChanges.listen(_handleAuthChange);
    if (!_isSupabaseConfigured && _user?.isGuest != true) {
      unawaited(continueAsGuest());
    }
  }

  final AuthRepository _repository;
  final bool _isSupabaseConfigured;
  late final StreamSubscription<AppUser?> _subscription;

  AuthStatus _status;
  AppUser? _user;
  bool _isBusy = false;
  String? _errorMessage;
  String? _infoMessage;
  String? _profileWarning;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _isBusy;
  bool get isSupabaseConfigured => _isSupabaseConfigured;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get profileWarning => _profileWarning;

  Future<void> continueAsGuest() async {
    await _runBusy(() async {
      final guestUser = await _repository.continueAsGuest();
      _user = guestUser;
      _status = AuthStatus.guest;
    }, failureMessage: 'Gastmodus konnte nicht gestartet werden.');
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(
      failureMessage: 'Anmeldung fehlgeschlagen',
      action: () => _repository.signInWithEmailPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    await _runAuthAction(
      failureMessage: 'Konto konnte nicht erstellt werden',
      action: () => _repository.signUpWithEmailPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _runBusy(() async {
      await _repository.sendPasswordResetEmail(email);
      _infoMessage = 'Passwort zurücksetzen';
    }, failureMessage: 'Netzwerkfehler. Bitte versuche es erneut.');
  }

  Future<void> signOut() async {
    await _runBusy(() async {
      await _repository.signOut();
      _user = null;
      _status = _isSupabaseConfigured ? AuthStatus.loggedOut : AuthStatus.guest;
    }, failureMessage: 'Netzwerkfehler. Bitte versuche es erneut.');
  }

  Future<void> _runAuthAction({
    required String failureMessage,
    required Future<AppUser> Function() action,
  }) async {
    await _runBusy(() async {
      final authenticatedUser = await action();
      _user = authenticatedUser;
      _status =
          authenticatedUser.isGuest ? AuthStatus.guest : AuthStatus.loggedIn;
      await _ensureProfileGracefully(authenticatedUser);
    }, failureMessage: failureMessage);
  }

  Future<void> _ensureProfileGracefully(AppUser authenticatedUser) async {
    try {
      await _repository.ensureProfileAndSettings(authenticatedUser);
      _profileWarning = null;
    } on Object {
      _profileWarning = 'Netzwerkfehler. Bitte versuche es erneut.';
    }
  }

  Future<void> _runBusy(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    if (_isBusy) return;

    _isBusy = true;
    _clearMessages();
    notifyListeners();
    try {
      await action();
    } on Object {
      _errorMessage = failureMessage;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _handleAuthChange(AppUser? changedUser) {
    if (changedUser == null) {
      if (_status != AuthStatus.guest) {
        _user = null;
        _status =
            _isSupabaseConfigured ? AuthStatus.loggedOut : AuthStatus.guest;
      }
    } else {
      _user = changedUser;
      _status = changedUser.isGuest ? AuthStatus.guest : AuthStatus.loggedIn;
    }
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    _profileWarning = null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
