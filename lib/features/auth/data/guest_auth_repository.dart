import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class GuestAuthRepository implements AuthRepository {
  const GuestAuthRepository();

  @override
  bool get isConfigured => false;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> get authStateChanges => Stream<AppUser?>.value(null);

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      Future.error(const AuthRepositoryUnavailableException());

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      Future.error(const AuthRepositoryUnavailableException());

  @override
  Future<void> signOut() async {}

  @override
  Future<AppUser> signUp({required String email, required String password}) =>
      Future.error(const AuthRepositoryUnavailableException());
}

class AuthRepositoryUnavailableException implements Exception {
  const AuthRepositoryUnavailableException();
}
