# Build Health

## Environment Snapshot
- Date (UTC): 2026-05-22
- Flutter version: unavailable in this execution environment (`flutter` command not found).
- Dart version: unavailable in this execution environment (`flutter`/`dart` commands not found).
- Note: Attempted Flutter SDK bootstrap via `https://storage.googleapis.com/flutter_infra_release/...` was blocked in this environment (HTTP 403), so local Flutter tooling could not be provisioned.

## Platform Configuration
- iOS Bundle ID: `de.driveassistant.ar`
- iOS display name: `DriveBot`
- iOS scheme name: `Runner`
- iOS workspace path: `ios/Runner.xcworkspace`

## Codemagic Workflows
- `ios-testflight`

## Commands Run
The following commands were attempted in this environment and could not run due to missing Flutter CLI:

- `flutter clean`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build ios --release --no-codesign`

## Known Blockers
- Local validation is blocked until Flutter SDK is available on `PATH`.
- Final build and signing confirmation must be completed in Codemagic (or any development machine with Flutter installed).
