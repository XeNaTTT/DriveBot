-- Create user profile and settings tables for the DriveBot MVP.
-- These tables intentionally stay UI-agnostic so app features can depend on
-- domain-specific repositories rather than Supabase implementation details.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (
    display_name is null or char_length(display_name) between 1 and 80
  ),
  constraint profiles_avatar_url_length check (
    avatar_url is null or char_length(avatar_url) <= 2048
  )
);

comment on table public.profiles is 'UI-agnostic account profile data owned by each authenticated user.';
comment on column public.profiles.id is 'Matches auth.users.id for a one-to-one user profile.';

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  distance_unit text not null default 'metric',
  speed_alerts_enabled boolean not null default true,
  weather_alerts_enabled boolean not null default true,
  roadwork_alerts_enabled boolean not null default true,
  high_contrast_hud boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_settings_distance_unit_valid check (
    distance_unit in ('metric', 'imperial')
  )
);

comment on table public.user_settings is 'Safe-driving preferences for each authenticated user.';
comment on column public.user_settings.high_contrast_hud is 'Defaults on to preserve the MVP safe-driving HUD principle.';

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

create trigger user_settings_set_updated_at
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

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

insert into public.profiles (id, display_name, avatar_url)
select
  id,
  nullif(raw_user_meta_data ->> 'display_name', ''),
  nullif(raw_user_meta_data ->> 'avatar_url', '')
from auth.users
on conflict (id) do nothing;

insert into public.user_settings (user_id)
select id
from auth.users
on conflict (user_id) do nothing;

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;

create policy "Users can read their own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

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

create policy "Users can update their own settings"
  on public.user_settings
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);


grant select, update on public.profiles to authenticated;
grant select, update on public.user_settings to authenticated;
