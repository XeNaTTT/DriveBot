# Build Health

## Environment Snapshot
- Date (UTC): 2026-05-22
- Flutter version: unavailable in this execution environment (`flutter` command not found).
- Dart version: unavailable in this execution environment (`flutter`/`dart` commands not found).

## Platform Configuration
- iOS Bundle ID: `de.driveassistant.ar`
- Android applicationId: `com.example.driveassistant_ar`
- iOS scheme name: `Runner`
- iOS workspace path: `ios/Runner.xcworkspace`

## Codemagic Workflows
- `ios-testflight`

## Commands Run
The following commands were attempted in this environment and failed because Flutter SDK is not installed in the runtime container:

- `flutter clean`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build ios --release --no-codesign`

## Known Blockers
- Local validation is blocked until Flutter SDK is available on PATH.
- Because build commands could not execute locally, final build confirmation must be completed by Codemagic (or any local/dev environment with Flutter installed).
