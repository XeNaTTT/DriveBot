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

## Account schema

The migration `supabase/migrations/20260528000000_create_profiles_and_user_settings.sql` creates:

- `public.profiles`
  - `user_id uuid primary key references auth.users(id)`
  - `email text`
  - `display_name text`
  - `created_at timestamptz`
  - `updated_at timestamptz`
  - `accepted_terms_at timestamptz null`
- `public.user_settings`
  - `user_id uuid primary key references auth.users(id)`
  - `preferred_camera_zoom numeric null`
  - `use_live_data boolean default true`
  - `show_debug_source_labels boolean default false`
  - `created_at timestamptz`
  - `updated_at timestamptz`

Row Level Security is enabled on both tables. Authenticated users can select,
insert, and update only rows where `auth.uid()` matches `user_id`; there are no
public read policies.

## Applying migrations safely

Only apply migrations to the non-production Supabase Dev project. If the CLI is
installed and `supabase status` clearly shows the Dev project, run:

```sh
supabase db push
```

If the CLI is unavailable or the linked project cannot be verified as Dev, do
not run database commands from the app repository. Apply the SQL in
`supabase/migrations/` manually in the Dev project SQL editor and then use
`docs/supabase-manual-test.md` to verify tables, RLS, and policies.

For future Codemagic release builds, these variables can be passed as optional
Dart defines without making them mandatory for the pipeline:

```sh
--dart-define=SUPABASE_URL=$SUPABASE_URL
--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```
