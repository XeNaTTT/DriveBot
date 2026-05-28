-- Create public profile and user settings tables for Supabase Auth users.
-- This migration intentionally contains schema and policies only; no real user data
-- or secrets should be committed to Git.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (
    display_name is null or char_length(display_name) <= 80
  ),
  constraint profiles_avatar_url_length check (
    avatar_url is null or char_length(avatar_url) <= 2048
  )
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  high_contrast_mode boolean not null default true,
  voice_alerts_enabled boolean not null default true,
  haptic_alerts_enabled boolean not null default true,
  preferred_units text not null default 'metric',
  warning_radius_meters integer not null default 5000,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_settings_preferred_units_valid check (
    preferred_units in ('metric', 'imperial')
  ),
  constraint user_settings_warning_radius_valid check (
    warning_radius_meters between 250 and 50000
  )
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create trigger set_user_settings_updated_at
before update on public.user_settings
for each row
execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;

create policy "Profiles are readable by authenticated users"
on public.profiles
for select
to authenticated
using (true);

create policy "Users can insert their own profile"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "Users can read their own settings"
on public.user_settings
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can insert their own settings"
on public.user_settings
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own settings"
on public.user_settings
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
