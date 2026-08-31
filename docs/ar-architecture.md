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

## Startup and marker placement update

The HUD keeps the native camera/AR background independent from warning loading so the camera can appear as soon as permissions and the runtime allow it. Warning repositories (community reports, Berlin traffic, Autobahn and other sources) refresh asynchronously after the HUD opens; marker layers consume the latest repository snapshot without recreating the camera or ARKit PlatformView.

Floating marker projection uses a stable horizon-based vertical placement model. Altitude is only reserved for future native projections where a reliable altitude exists. Without reliable altitude, remote objects stay near the visual horizon, nearby objects can sit slightly lower, pitch adjusts the horizon gently, and tracking-limited states reduce vertical movement. A decluttering pass prioritizes selected objects, mobile/fixed speed cameras, charging targets, severe warnings and then lower-priority traffic hints, stacking or hiding overlapping cards and surfacing the hidden count as “+X weitere”.

The fallback hierarchy is:
1. ARKit anchored/projection result when native AR and stable tracking are available.
2. Bearing/FOV projection with stable horizon placement when heading/location data is available.
3. Bottom warning card only when floating placement is not safe.

## Geo-AR anchoring update

DriveBot now follows the ARKit + CoreLocation reference pattern more closely:
Flutter creates stable geo anchor candidates, converts coordinates into a local
East/North/Up tangent plane for testability, and sends the native iOS layer the
current user coordinate, heading, target coordinate and stable target id. The
iOS `ARSCNView` keeps a session origin, maps targets to ARKit world space with
`x = east`, `y = up`, `z = -north`, keeps anchors by stable id, and uses the
active `ARFrame.camera.projectPoint` result as the preferred marker screen
position. Flutter only renders the existing German marker UI at the native
screen coordinates; bearing/FOV/horizon projection remains as fallback.

Recalibration is intentionally threshold-based rather than per-frame: targets
are recalculated when the user moves meaningfully, heading drift exceeds the
configured threshold, or ARKit tracking state changes. Expired warnings are
filtered before AR projection, and sensor/AR ticks do not refetch warning data.

On iOS, geographic offsets and movement thresholds are calculated directly
with MapKit (`MKMapPoint`) and Core Location (`CLLocation.distance`) instead of
repeating a custom spherical approximation for every marker. The native runtime
caches the MapKit origin and meter scale once per recalibration, uses the
shortest offset across the date line, and passes the resulting local coordinates
straight to ARKit's SIMD world-space APIs. Flutter remains responsible only for
the UI-agnostic anchor payload and marker presentation.
