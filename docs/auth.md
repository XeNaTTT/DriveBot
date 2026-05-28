# Supabase Auth integration

DriveBot uses Supabase Auth only when `SUPABASE_URL` and `SUPABASE_ANON_KEY`
are supplied as Flutter Dart defines. Missing or invalid configuration must not
block startup: the app enters guest mode and keeps the driving HUD available.

The Flutter client uses the public anon key only. It never uses a Supabase
service role key and relies on the backend RLS policies for `public.profiles`
and `public.user_settings`.

## Runtime behavior

- Supabase configured and no session: show the German login screen with a guest
  option.
- Supabase configured and authenticated: upsert the user's profile/settings and
  show the HUD.
- Supabase missing or unavailable: continue directly in guest mode and show the
  HUD.
- Profile/settings upsert failures are reported as a safe German network warning
  but do not crash login or signup.

## Codemagic

The iOS IPA build passes these Dart defines from Codemagic environment
variables:

```sh
--dart-define=SUPABASE_URL=$SUPABASE_URL
--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

Signing, bundle ID, Apple Team ID, CocoaPods, Shorebird, and Android build
settings remain unchanged.
