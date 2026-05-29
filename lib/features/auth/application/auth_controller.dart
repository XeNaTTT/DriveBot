import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_settings.dart';

enum AuthStatus { guest, loggedOut, loggedIn }

final class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required bool isSupabaseConfigured,
  }) : _repository = repository,
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
  late UserSettings _settings = _repository.currentSettings;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _isBusy;
  bool get isSupabaseConfigured => _isSupabaseConfigured;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get profileWarning => _profileWarning;
  UserSettings get settings => _settings;

  Future<void> continueAsGuest() async {
    await _runBusy(() async {
      final guestUser = await _repository.continueAsGuest();
      _user = guestUser;
      _settings = UserSettings(userId: guestUser.id);
      _status = AuthStatus.guest;
    }, failureMessage: 'Gastmodus konnte nicht gestartet werden.');
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(
      failureMessage: 'Anmeldung fehlgeschlagen',
      action: () =>
          _repository.signInWithEmailPassword(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    await _runAuthAction(
      failureMessage: 'Konto konnte nicht erstellt werden',
      action: () =>
          _repository.signUpWithEmailPassword(email: email, password: password),
    );
  }

  Future<void> signInWithApple() async {
    await _runAuthAction(
      failureMessage: 'Apple-Anmeldung fehlgeschlagen',
      action: _repository.signInWithApple,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (!_looksLikeEmail(trimmedEmail)) {
      _errorMessage = 'Ungültige E-Mail-Adresse.';
      notifyListeners();
      return;
    }

    await _runBusy(() async {
      await _repository.sendPasswordResetEmail(email);
      _infoMessage = 'Passwort zurücksetzen';
    }, failureMessage: 'Netzwerkfehler. Bitte versuche es erneut.');
  }

  Future<void> signOut() async {
    await _runBusy(() async {
      await _repository.signOut();
      _user = null;
      _settings = const UserSettings.guest();
      _status = _isSupabaseConfigured ? AuthStatus.loggedOut : AuthStatus.guest;
    }, failureMessage: 'Netzwerkfehler. Bitte versuche es erneut.');
  }

  Future<void> setShowDebugSourceLabels(bool value) async {
    await _runBusy(() async {
      final currentUser = _user ?? const AppUser.guest();
      final updated = _settings.copyWith(
        userId: currentUser.id,
        showDebugSourceLabels: value,
      );
      _settings = await _repository.updateSettings(updated);
    }, failureMessage: 'Einstellung konnte nicht gespeichert werden.');
  }

  Future<void> _runAuthAction({
    required String failureMessage,
    required Future<AppUser> Function() action,
  }) async {
    if (!_isSupabaseConfigured) {
      _errorMessage = 'Supabase ist nicht konfiguriert.';
      notifyListeners();
      return;
    }

    await _runBusy(() async {
      final authenticatedUser = await action();
      _user = authenticatedUser;
      _settings = UserSettings(userId: authenticatedUser.id);
      _status = authenticatedUser.isGuest
          ? AuthStatus.guest
          : AuthStatus.loggedIn;
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
    } on Object catch (error) {
      _errorMessage = _mapAuthError(error, fallback: failureMessage);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _handleAuthChange(AppUser? changedUser) {
    if (changedUser == null) {
      if (_status != AuthStatus.guest) {
        _user = null;
        _status = _isSupabaseConfigured
            ? AuthStatus.loggedOut
            : AuthStatus.guest;
      }
    } else {
      _user = changedUser;
      _settings = UserSettings(userId: changedUser.id);
      _status = changedUser.isGuest ? AuthStatus.guest : AuthStatus.loggedIn;
    }
    notifyListeners();
  }

  String _mapAuthError(Object error, {required String fallback}) {
    final message = error.toString().toLowerCase();
    if (message.contains('invalid') && message.contains('email')) {
      return 'Ungültige E-Mail-Adresse.';
    }
    if (message.contains('password') || message.contains('credential')) {
      return 'Falsches Passwort oder unbekanntes Konto.';
    }
    if (message.contains('confirm') ||
        message.contains('bestätig') ||
        message.contains('bestaetig')) {
      return 'Bitte bestätige deine E-Mail-Adresse, bevor du dich anmeldest.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('timeout')) {
      return 'Netzwerkfehler. Bitte versuche es erneut.';
    }
    return fallback.isEmpty ? 'Unbekannter Fehler.' : fallback;
  }

  bool _looksLikeEmail(String email) =>
      email.contains('@') && email.contains('.') && !email.contains(' ');

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
