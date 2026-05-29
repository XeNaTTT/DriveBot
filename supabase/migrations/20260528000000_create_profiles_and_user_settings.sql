-- Create DriveBot account profile and user settings tables.
-- This migration contains schema and Row Level Security policies only.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  accepted_terms_at timestamptz
);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  preferred_camera_zoom numeric,
  use_live_data boolean default true,
  show_debug_source_labels boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;

drop policy if exists "Authenticated users can select own profile" on public.profiles;
drop policy if exists "Authenticated users can insert own profile" on public.profiles;
drop policy if exists "Authenticated users can update own profile" on public.profiles;
drop policy if exists "Authenticated users can select own settings" on public.user_settings;
drop policy if exists "Authenticated users can insert own settings" on public.user_settings;
drop policy if exists "Authenticated users can update own settings" on public.user_settings;

create policy "Authenticated users can select own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "Authenticated users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "Authenticated users can update own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "Authenticated users can select own settings"
  on public.user_settings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Authenticated users can insert own settings"
  on public.user_settings
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Authenticated users can update own settings"
  on public.user_settings
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
