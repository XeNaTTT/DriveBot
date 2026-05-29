import 'app_user.dart';
import 'user_settings.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  UserSettings get currentSettings;

  Stream<AppUser?> get authStateChanges;

  Future<AppUser> continueAsGuest();

  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmailPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();

  Future<void> ensureProfileAndSettings(AppUser user);

  Future<UserSettings> updateSettings(UserSettings settings);
}
