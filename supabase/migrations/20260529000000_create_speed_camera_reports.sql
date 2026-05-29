create table if not exists public.speed_camera_reports (
  id uuid primary key default gen_random_uuid(),
  report_type text not null check (report_type in ('mobile', 'fixed')),
  user_id uuid nullable references auth.users(id) on delete set null,
  latitude double precision not null,
  longitude double precision not null,
  location_accuracy_meters double precision nullable,
  heading_degrees double precision nullable,
  speed_kmh double precision nullable,
  camera_zoom_label text nullable,
  app_mode text nullable check (app_mode in ('liveAr', 'partialLive', 'fallback')),
  confidence text not null default 'low' check (confidence in ('high', 'medium', 'low')),
  source text not null default 'community',
  moderation_status text not null default 'active' check (moderation_status in ('active', 'hidden', 'rejected')),
  verification_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create or replace function public.set_speed_camera_report_expiry()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();

  if new.created_at is null then
    new.created_at = now();
  end if;

  if new.report_type = 'mobile' then
    new.expires_at = new.created_at + interval '3 days';
  elsif new.report_type = 'fixed' then
    new.expires_at = new.created_at + interval '1 year';
  end if;

  return new;
end;
$$;

drop trigger if exists speed_camera_reports_set_expiry on public.speed_camera_reports;
create trigger speed_camera_reports_set_expiry
before insert or update of report_type, created_at
on public.speed_camera_reports
for each row
execute function public.set_speed_camera_report_expiry();

alter table public.speed_camera_reports enable row level security;

drop policy if exists "Select active community reports" on public.speed_camera_reports;
create policy "Select active community reports"
on public.speed_camera_reports
for select
to anon, authenticated
using (
  moderation_status = 'active'
  and expires_at > now()
);

drop policy if exists "Insert own reports" on public.speed_camera_reports;
create policy "Insert own reports"
on public.speed_camera_reports
for insert
to authenticated
with check (
  user_id = auth.uid()
  and report_type in ('mobile', 'fixed')
  and latitude is not null
  and longitude is not null
  and moderation_status = 'active'
);

drop policy if exists "Update own reports" on public.speed_camera_reports;
create policy "Update own reports"
on public.speed_camera_reports
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
