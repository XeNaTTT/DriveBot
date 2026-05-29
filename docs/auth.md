# DriveBot Auth Foundation

DriveBot supports Supabase email/password accounts while keeping the HUD usable
in guest mode. Supabase Auth is optional at runtime: missing or invalid
configuration must not block startup, and the app must never require login to
use the driving HUD.

The Flutter client uses the public Supabase anon key only. It never uses a
Supabase service role key and relies on backend RLS policies for
`public.profiles` and `public.user_settings`.

## Runtime behavior

- The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Flutter Dart
  defines.
- If both values are present, the Flutter app initializes Supabase and listens
  for auth state changes.
- If either value is missing, or initialization fails, initialization is skipped
  and DriveBot starts directly in `Gastmodus`; the Supabase notice is available
  from the account menu behind the top-right profile icon instead of covering
  the HUD.
- Supabase configured and no session: show the German login screen with a guest
  option.
- Supabase configured and authenticated with a real Supabase session: upsert the
  user's profile/settings and show the HUD.
- Login is optional. Users can choose `Ohne Konto fortfahren` and keep using the
  HUD without an account.
- Signing out returns safely to the logged-out auth state; the user can sign in
  again or continue as a guest.
- Sign-up responses that require email confirmation but do not include a session
  stay logged out and ask the user to confirm their email before signing in.
- Profile/settings upsert failures are reported as a safe German network warning
  but do not crash login or signup.

## Supported flows

- `Anmelden` with email/password.
- `Konto erstellen` with email/password.
- `Passwort vergessen?` / `Passwort zurücksetzen` email flow.
- `Ohne Konto fortfahren` guest flow.
- Account menu from the top-right profile icon, including the missing-Supabase
  guest-mode notice when applicable.
- `Abmelden` from the profile screen.
- Compact profile settings with a `Datenquellen anzeigen` debug-source toggle.
- Auth state listener through the repository/controller boundary.

## Architecture

Auth is feature-scoped under `lib/features/auth`:

- `domain/` contains UI-agnostic user, profile/settings models, and repository contracts.
- `data/` contains guest and Supabase repository implementations.
- `application/` owns `AuthController` state transitions.
- `presentation/` owns the auth gate, login screen, profile entry point, and
  profile screen.

The HUD remains feature-owned. Auth UI is composed around the HUD through
constructor injection, so camera, sensor, AR, warning, and reporting behavior
stay independent from the auth provider.

## Codemagic

The iOS IPA build passes these Dart defines from Codemagic environment
variables:

```sh
--dart-define=SUPABASE_URL=$SUPABASE_URL
--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

Signing, bundle ID, Apple Team ID, CocoaPods, Shorebird, Android build settings,
AppIcon, and existing Codemagic signing configuration remain unchanged.
