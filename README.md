# DriveAssistant AR

DriveAssistant AR is a mobile Flutter app prototype for a **minimal, safety-focused, head-up-display (HUD) driving assistant**.

This repository currently contains a **mock-data MVP** and architecture foundation for later integration of real public data sources (e.g. OpenStreetMap/Overpass, Open-Meteo/Bright Sky, Autobahn API, Tankerkönig, charging APIs, OpenRouteService).

## Current MVP Scope

- Camera-style placeholder background
- Top status bar with mock:
  - speed
  - heading
  - GPS status
- Central HUD overlay panel
- Warning cards for nearby mock items:
  - speed camera
  - speed limit
  - roadwork
  - weather warning
  - charging station
- Modular architecture with mock repositories/services

## Project Structure

- `lib/app` — app shell, routing, bootstrapping
- `lib/features/hud` — HUD UI + domain models and mock data service
- `lib/features/location` — location domain abstractions + mock service
- `lib/features/data_sources` — source metadata abstractions + mock registry
- `lib/shared` — reusable theme, models, widgets/utilities
- `docs` — product and data planning docs

## Setup

### Prerequisites

- Flutter SDK (stable channel)
- Dart SDK (comes with Flutter)
- Android Studio or Xcode tooling depending on target

### Install & Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

If `flutter` is not available in your PATH, install Flutter and run `flutter doctor` first.

## Next Steps

1. Replace mock repositories with real API adapters.
2. Add camera plugin integration for real background feed.
3. Add permissions and safe-driving UX constraints.
4. Add map matching, route context, and confidence scoring.

## Deploy to TestFlight without a Mac

Use Codemagic cloud builds for iOS/TestFlight deployment. See the step-by-step guide in [`docs/codemagic-testflight.md`](docs/codemagic-testflight.md).

