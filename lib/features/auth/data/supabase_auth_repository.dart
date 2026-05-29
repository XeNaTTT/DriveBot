import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_settings.dart';

final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  static const UserSettings _fallbackSettings = UserSettings.guest();

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentSession?.user);

  @override
  UserSettings get currentSettings {
    final user = currentUser;
    if (user == null) return _fallbackSettings;
    return UserSettings(userId: user.id);
  }

  @override
  Stream<AppUser?> get authStateChanges => _client.auth.onAuthStateChange.map(
    (event) => _mapUser(event.session?.user),
  );

  @override
  Future<AppUser> continueAsGuest() async => const AppUser.guest();

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return _requireAuthenticatedSession(response.session);
  }

  @override
  Future<AppUser> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return _requireAuthenticatedSession(response.session);
  }

  @override
  Future<AppUser> signInWithApple() async {
    final response = await _client.auth.signInWithApple();
    return _requireAuthenticatedSession(response.session);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> ensureProfileAndSettings(AppUser user) async {
    if (user.isGuest) return;

    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'updated_at': updatedAt,
    });
    await _client.from('user_settings').upsert({
      'user_id': user.id,
      'updated_at': updatedAt,
    });
  }

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    await _client.from('user_settings').upsert({
      'user_id': settings.userId,
      'preferred_camera_zoom': settings.preferredCameraZoom,
      'use_live_data': settings.useLiveData,
      'show_debug_source_labels': settings.showDebugSourceLabels,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return settings;
  }

  AppUser _requireAuthenticatedSession(Session? session) {
    final mapped = _mapUser(session?.user);
    if (mapped == null) {
      throw const AuthException(
        'Bitte bestätige deine E-Mail-Adresse, bevor du dich anmeldest.',
      );
    }
    return mapped;
  }

  static AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser.authenticated(id: user.id, email: user.email);
  }
}

extension SupabaseAppleSignIn on GoTrueClient {
  Future<AuthResponse> signInWithApple() async {
    final rawNonce = generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple hat kein ID-Token zurückgegeben.');
    }

    return signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }
}
