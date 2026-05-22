# Data Sources Plan (Future Integrations)

This document defines target data providers and adapter strategy. **No live integrations are included in current MVP**.

## Planned Sources
- OpenStreetMap + Overpass: static/contextual map objects (speed cameras, road metadata).
- Speed limit datasets (regional overlays as available).
- Open-Meteo / Bright Sky: weather context and warnings.
- Autobahn API: roadworks, incidents, closures.
- Tankerkönig: fuel station prices.
- Charging infrastructure APIs: EV charging points and availability.
- Accident hotspot datasets: risk layers.
- OpenRouteService: routing and corridor context.

## Adapter Strategy
Each provider should be integrated through a dedicated data adapter in `lib/features/data_sources/data/` with:
- transport client abstraction
- mapping to domain models
- retry/timeouts and graceful degradation
- provider-specific rate-limit policies

## Repository Strategy
Feature repositories consume one or more data-source adapters and merge into feature-level domain entities (e.g. `HudWarningItem`).

## Safety & Compliance Notes
- Respect API licenses and attribution requirements.
- Minimize personally identifying data handling.
- Ensure legal compliance for driver assistance UI messaging in target regions.
