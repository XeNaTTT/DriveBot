# AR Architecture (MVP Mock-First + iOS Sensor Runtime)

## Overview
The AR layer remains mock-first and sensor-driven. Warning data still comes from `MockHudRepository`. On iPhone builds, runtime location values are requested via `geolocator` (When In Use) and fed into the HUD, with robust fallback to mock values when permissions/services/sensors are unavailable.

## Runtime Signal Flow
- `IosLocationRuntime` implements both `LocationRepository` and `PermissionRepository`.
- `HudScreen` listens via `ValueListenableBuilder` for live status updates.
- Permission outcomes covered:
  - granted
  - denied
  - permanently denied
  - service disabled / unavailable
- Fallback behavior:
  - GPS speed unavailable (null/invalid) -> mock speed
  - heading unavailable -> mock heading
  - permission or service unavailable -> limited fallback mode with clear UI label

## Distance + Bearing Placement
- `BearingToArPositionMapper` converts warning bearing/distance into a stable relative AR position.
- Inputs:
  - user heading degrees
  - warning bearing degrees
  - warning distance meters
- Output:
  - horizontal alignment (`-1` left to `1` right)
  - vertical bias for perceived depth
  - normalized (clamped) distance

## Warning Prioritization
Warnings are sorted for AR display and primary HUD selection with this fixed order:
1. speed camera
2. roadwork
3. speed limit
4. weather warning
5. charging/fuel POI

Distance is used as the tie-breaker inside the same warning type.
