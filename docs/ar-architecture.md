# AR Architecture (MVP Sensor Runtime + API/Fallback Warnings)

## Overview

The AR layer renders warning markers over either the live camera preview or a
safe fallback HUD grid. Runtime sensor data drives speed, heading, mode labels,
and marker projection when available. Warning objects can be API-backed
(Open-Meteo and Autobahn API) or mocked through the fallback warning repository.

## Runtime signal flow

- `IosLocationRuntime` implements both `LocationRepository` and
  `PermissionRepository` on iOS.
- `HudScreen` listens via `ValueListenableBuilder` for location and permission
  updates.
- `CameraHudBackground` reports its runtime state to `HudScreen` so debug builds
  can distinguish a ready live camera from the fallback grid.
- Back camera selection prefers the ultra-wide lens when exposed by the device,
  and the HUD zoom control can switch between separate ultra-wide and wide back
  cameras when optical zoom bounds do not expose a 0.5x value.
- Permission outcomes covered:
  - granted
  - denied
  - permanently denied
  - service disabled / unavailable

## Fallback behavior

- Camera unavailable or denied -> drawn fallback HUD grid.
- GPS/sensor services unavailable -> `MockLocationRepository` values.
- Heading unavailable -> mock heading is used until compass or GPS course is
  available.
- APIs fail, time out, cannot parse, have no current location, or return no
  warnings -> `MockWarningRepository` supplies static warnings.
- Debug builds show source pills for camera, location, and warnings to prevent
  mock data from being mistaken for live data.

## Distance + bearing placement

`ArProjectionMapper` projects `HudWarningItem` values into marker positions.
Inputs:

- user heading degrees from `LocationStatus.headingDegrees`
- warning bearing degrees from API/fallback warning objects
- warning distance meters from API/fallback warning objects

Output:

- normalized horizontal position within the configured field of view
- vertical position based on clamped distance for simple depth perception

## Warning prioritization

Warnings are sorted by distance for the current HUD display. Autobahn warnings are additionally filtered to coordinated entries within 5 km and within the configured AR field of view, with ahead-of-user entries preferred before the HUD displays them. The first projected
marker is used for the primary warning card; if no marker is inside the field of
view, the nearest warning is shown in the card.
