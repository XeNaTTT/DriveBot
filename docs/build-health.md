# Build Health

## Environment Snapshot
- Date (UTC): 2026-05-26
- Flutter version: unavailable in this execution environment (`flutter` command not found).
- Dart version: unavailable in this execution environment (`dart` command not found).
- Impact: automated local quality checks could not be executed in this container.

## Flutter Quality Checks
Planned and required checks for this branch:
- `dart format .`
- `flutter analyze`
- `flutter test`

Current local status (this environment):
- `dart format .` → failed: CLI not installed.
- `flutter analyze` → failed: CLI not installed.
- `flutter test` → blocked: Flutter CLI not installed.

## Responsive HUD Coverage (Widget Tests)
Updated widget tests in `test/hud_screen_test.dart` now validate:
- Compact phone constraints render without exceptions.
- Normal iPhone constraints with large text scale render without exceptions.
- Primary warning and speed camera warning cards are found by stable `Key` values.
- Empty warning state is rendered when warning list is empty.
- Permission denied fallback banner is rendered by stable `Key`.
- Tap interaction on warning cards remains stable.

## TestFlight Readiness (iOS-first MVP)
- Bundle ID remains `de.driveassistant.ar`.
- App name remains `DriveBot` in architecture/UX copy.
- iOS-first HUD UX hardened with responsive constraints, semantics, and safer composition.
- **Readiness note:** Final readiness still depends on running `flutter analyze` and `flutter test` in CI or a machine with Flutter installed.

## Known Limitations
- Live AR/camera/location integration is still mocked for MVP safety.
- Permission fallback UX provides limited-mode behavior only; no runtime permission request flow is implemented here.
- Local build validation is blocked by missing Flutter and Dart CLIs in this environment.

## Mock Data Status
The following remain mock-backed by design for MVP user testing:
- HUD warnings (`MockHudRepository`)
- Location/speed/heading (`MockLocationRepository`)
- Sensor permission state (`MockPermissionRepository`)
- Data source registry (`MockDataSourceRegistry`)
