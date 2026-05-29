import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  bool get isConfigured => true;

  @override
  AppUser? get currentUser => _client.auth.currentUser?.toAppUser();

  @override
  Stream<AppUser?> get authStateChanges => _client.auth.onAuthStateChange
      .map((event) => event.session?.user.toAppUser());

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthUserMissingException();
    return user.toAppUser();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<AppUser> signUp(
      {required String email, required String password}) async {
    final response =
        await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) throw const AuthUserMissingException();
    await _upsertProfile(user);
    return user.toAppUser();
  }

  Future<void> _upsertProfile(supabase.User user) async {
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on Object {
      // Profile creation must not block authentication.
    }
  }
}

class AuthUserMissingException implements Exception {
  const AuthUserMissingException();
}

extension on supabase.User {
  AppUser toAppUser() => AppUser(
        id: id,
        email: email,
        displayName: userMetadata?['display_name'] as String?,
      );
}
