import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

enum AuthStatus { loading, guest, unauthenticated, authenticated }

@immutable
class AuthState {
  const AuthState._({required this.status, this.user, this.message});

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.guest(AppUser user)
      : this._(status: AuthStatus.guest, user: user);

  const AuthState.unauthenticated({String? message})
      : this._(status: AuthStatus.unauthenticated, message: message);

  const AuthState.authenticated(AppUser user)
      : this._(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final AppUser? user;
  final String? message;

  bool get showsHud =>
      status == AuthStatus.guest || status == AuthStatus.authenticated;
}

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required bool supabaseConfigured,
  })  : _repository = repository,
        _supabaseConfigured = supabaseConfigured {
    _subscription = _repository.authStateChanges.listen(_applyUser);
    final currentUser = _repository.currentUser;
    if (!_supabaseConfigured) {
      continueAsGuest();
    } else {
      _applyUser(currentUser);
    }
  }

  final AuthRepository _repository;
  final bool _supabaseConfigured;
  late final StreamSubscription<AppUser?> _subscription;

  AuthState _state = const AuthState.loading();
  AuthState get state => _state;

  Future<void> continueAsGuest() async {
    await _run(() async => _applyUser(await _repository.continueAsGuest()));
  }

  Future<void> signIn({required String email, required String password}) async {
    await _run(() async =>
        _applyUser(await _repository.signIn(email: email, password: password)));
  }

  Future<void> signUp({required String email, required String password}) async {
    await _run(() async =>
        _applyUser(await _repository.signUp(email: email, password: password)));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _run(() => _repository.sendPasswordResetEmail(email));
  }

  Future<void> signOut() async {
    await _run(() async {
      await _repository.signOut();
      _setState(const AuthState.unauthenticated());
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _setState(AuthState.unauthenticated(message: error.toString()));
    }
  }

  void _applyUser(AppUser? user) {
    if (user == null) {
      _setState(const AuthState.unauthenticated());
    } else if (user.isGuest) {
      _setState(AuthState.guest(user));
    } else {
      _setState(AuthState.authenticated(user));
    }
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
