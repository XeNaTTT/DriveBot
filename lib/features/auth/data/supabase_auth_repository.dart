import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> get authStateChanges => _client.auth.onAuthStateChange
      .map((state) => _mapUser(state.session?.user));

  @override
  Future<AppUser> continueAsGuest() async => const AppUser.guest();

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return _mapUser(response.user) ?? const AppUser.guest();
  }

  @override
  Future<AppUser> signUp(
      {required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return _mapUser(response.user) ?? const AppUser.guest();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  static AppUser? _mapUser(supabase.User? user) {
    if (user == null) return null;
    return AppUser(id: user.id, email: user.email);
  }
}
