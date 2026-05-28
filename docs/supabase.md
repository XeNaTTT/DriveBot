# Supabase Setup

DriveBot stores Supabase database changes in Git so backend setup can be reviewed alongside app code.

## Project layout

- Supabase GitHub integration working directory: `supabase`.
- Migrations live under `supabase/migrations`.
- `supabase/seed.sql` is intentionally a placeholder for local development only.

## Secrets and client keys

- Do not commit secrets in Git.
- Do not commit `.env` files.
- Flutter must use the publishable/anon key only.
- Never use the `service_role` key in Flutter.
- Keep production credentials outside the repository and inject values with `--dart-define` or CI secret storage.

## Flutter environment values

Use placeholders from `.env.example` to configure local values outside Git:

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

Example local run command:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=replace-with-anon-key
```

If either value is omitted, DriveBot starts in guest mode and the HUD remains available.
