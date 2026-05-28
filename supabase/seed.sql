-- Local development seed data for profile-dependent repositories.
-- Auth users are intentionally not inserted here because Supabase manages them
-- through auth flows; application tables receive example rows only when matching
-- local auth user IDs exist.

insert into public.profiles (id, display_name, avatar_url)
select id, 'DriveBot Demo Driver', null
from auth.users
where email = 'demo@drivebot.local'
on conflict (id) do update
set display_name = excluded.display_name;

insert into public.user_settings (
  user_id,
  distance_unit,
  speed_alerts_enabled,
  weather_alerts_enabled,
  roadwork_alerts_enabled,
  high_contrast_hud
)
select id, 'metric', true, true, true, true
from auth.users
where email = 'demo@drivebot.local'
on conflict (user_id) do update
set distance_unit = excluded.distance_unit,
    speed_alerts_enabled = excluded.speed_alerts_enabled,
    weather_alerts_enabled = excluded.weather_alerts_enabled,
    roadwork_alerts_enabled = excluded.roadwork_alerts_enabled,
    high_contrast_hud = excluded.high_contrast_hud;
