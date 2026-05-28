# DriveBot Auth Foundation

DriveBot supports Supabase email/password accounts while keeping the HUD usable in guest mode.

## Runtime behavior

- The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` with Dart `String.fromEnvironment` values.
- If both values are present, the Flutter app initializes Supabase and listens for auth state changes.
- If either value is missing, initialization is skipped and the app starts directly in `Gastmodus`.
- Login is optional. Users can choose `Ohne Konto fortfahren` and keep using the HUD without an account.
- Signing out returns to the logged-out auth state safely; the user can sign in again or continue as a guest.

## Supported flows

- `Anmelden` with email/password.
- `Konto erstellen` with email/password.
- `Passwort vergessen?` / `Passwort zurücksetzen` email flow.
- `Abmelden` from the profile screen.
- Auth state listener through the repository/controller boundary.

## Architecture

Auth is feature-scoped under `lib/features/auth`:

- `domain/` contains UI-agnostic user and repository contracts.
- `data/` contains guest and Supabase repository implementations.
- `application/` owns `AuthController` state transitions.
- `presentation/` owns the auth gate, login screen, and profile screen.

The HUD remains feature-owned and receives a small account entry widget through constructor injection.
