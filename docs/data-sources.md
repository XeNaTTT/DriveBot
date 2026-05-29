# Data Sources and HUD Source Audit

This document tracks which HUD values are backed by live integrations and which
values still use MVP fallback data. Keep it in sync with changes to the HUD data
pipeline.

## Current HUD values

| Displayed information | Current source | Live when | Fallback/mock behavior |
| --- | --- | --- | --- |
| Camera background | Device back camera via `CameraHudBackground` and `camera` plugin | Camera permission is granted and the camera controller initializes successfully | A drawn HUD grid is shown when permission is denied, no camera exists, or initialization fails |
| Speed (`Tempo … km/h`) | `LocationStatus.speedKph` from `IosLocationRuntime` on iOS | Geolocator reports a finite non-negative GPS speed | `MockLocationRepository` reports 84 km/h when sensors/services are unavailable; stationary/unknown live speed maps to 0 km/h |
| Heading (`Richtung …`) | Compass heading from `flutter_compass`, then GPS course from geolocator | Compass or GPS heading is available | Mock heading 58° / NE is used when live heading is unavailable |
| Location health / mode | `LocationStatus.gpsFixStatus`, permissions, and camera runtime state | GPS fix is live and not marked mock, heading is live, and camera is ready | Fallback mode is shown when the HUD is driven by mock sensor values |
| Primary warning card | `CompositeWarningRepository` | Open-Meteo or filtered Autobahn API warnings return warning objects, including cached API results | `MockWarningRepository` supplies static warning objects when APIs fail, time out, cannot parse, have no current location, or return no warnings |
| AR markers | Projected from the same warning objects through `ArProjectionMapper` | Autobahn warnings are pre-filtered to entries with coordinates inside 5 km and within the AR field of view; marker titles/distances/bearings are API-backed only when the warning repository is API-backed | Static mock warnings are projected into AR when fallback warnings are active |

## Debug/source indicator

In Flutter debug builds the HUD shows a compact source indicator:

- `Kamera: Live` only when the camera controller is ready; otherwise `Kamera: Fallback`.
- `Standort: Live` only when the location fix is live and not marked mock; otherwise `Standort: Fallback`.
- `Warnungen: API` or `Warnungen: API-Cache` for API-backed warning data; `Warnungen: Mock` for fallback warnings.

## User-facing source labels

The primary warning card uses German source labels:

- `Live-Daten` only for warning data that came from a real API path (`liveApi` or cached API warnings).
- `Fallback-Daten` for mock warning data, empty API results, or API failures that fall back to mock warnings.

## Integrated and planned providers

### Integrated in the MVP

- Open-Meteo: weather-related driving warnings.
- Autobahn API: roadwork, warning, and closure items for the configured road ID via `/o/autobahn/{roadId}/services/roadworks`, `/warnings`, and `/closures`; entries without coordinates, outside 5 km, or outside the AR field of view are ignored before they reach the HUD.
- iOS sensors: camera availability, GPS speed/course, compass heading, and motion availability.

### Still planned / not yet integrated

- OpenStreetMap + Overpass: static/contextual map objects such as speed cameras and road metadata.
- Dedicated speed-limit datasets.
- Tankerkönig fuel prices.
- Charging infrastructure availability APIs.
- Accident hotspot datasets.
- OpenRouteService routing and corridor context.

## Adapter strategy

Each provider should remain behind a feature-level adapter/repository with:

- transport client abstraction
- mapping to UI-agnostic domain models with provider metadata (for example `source`, `roadId`, coordinates, validity, distance, bearing, and severity)
- retry/timeouts and graceful degradation
- provider-specific rate-limit and attribution handling

Feature repositories consume one or more data-source adapters and merge them into
feature-level domain entities such as `HudWarningItem`.
