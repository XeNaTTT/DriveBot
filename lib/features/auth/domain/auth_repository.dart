import 'app_user.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  Stream<AppUser?> get authStateChanges;

  Future<AppUser> continueAsGuest();

  Future<AppUser> signUp({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
