# Build Health

## Environment Snapshot
- Date (UTC): 2026-05-26
- Flutter version: unavailable in this execution environment (`flutter` command not found).
- Dart version: unavailable in this execution environment (`dart` command not found).
- Impact: automated local quality checks could not be executed in this container.

## Codemagic Static Analysis Simulation
What was validated locally (configuration-level checks):
- `codemagic.yaml` workflow structure parses cleanly and keeps one iOS TestFlight workflow.
- Added deterministic diagnostics and quality gates:
  - `flutter --version`, `dart --version`, `xcodebuild -version`
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
- Added dependency caching for pub and CocoaPods to reduce flaky cold builds.
- Added explicit trigger policy for pushes to `main` so release automation is predictable.

## Flutter Quality Checks
Planned and required checks for this branch:
- `dart format .`
- `flutter analyze`
- `flutter test`

Current local status (this environment):
- `dart format .` → failed: CLI not installed.
- `flutter analyze` → failed: CLI not installed.
- `flutter test` → blocked: Flutter CLI not installed.

## TestFlight Readiness (iOS-first MVP)
- Bundle ID remains `de.driveassistant.ar`.
- iOS workflow keeps profile application via `xcode-project use-profiles`.
- IPA export still uses Codemagic export options plist path.
- **Readiness note:** Final readiness still depends on CI execution of `flutter analyze` and `flutter test` on Codemagic macOS runners.

## Known Limitations
- Live AR/camera/location integration is still mocked for MVP safety.
- Permission fallback UX provides limited-mode behavior only; no runtime permission request flow is implemented here.
- Local build validation is blocked by missing Flutter and Dart CLIs in this environment.

## iOS Runner Target Recovery (2026-05-26)
- Repaired malformed iOS project metadata by regenerating the iOS platform with `flutter create --platforms=ios --overwrite .` and reapplying project-specific settings.
- Confirmed `Runner` is an iOS app target in `ios/Runner.xcodeproj/project.pbxproj` with:
  - `SDKROOT = iphoneos`
  - `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`
  - `TARGETED_DEVICE_FAMILY = "1,2"` (includes iPhone)
  - `PRODUCT_BUNDLE_IDENTIFIER = de.driveassistant.ar`
  - `DEVELOPMENT_TEAM = QLQ959FUNR`
- Confirmed `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` references `Runner.app` and the `Runner` target within `Runner.xcodeproj` (iOS target).
- Generic iOS destination should now be discoverable again because the Runner target now declares iOS SDK/platform and device family.
- Migration files are committed on this branch, including project/scheme/plist/config workspace updates produced by the safe iOS platform regeneration.

## Camera Dependency Validation Gate (2026-05-27)
- `flutter pub get` was attempted before camera/HUD implementation and initially succeeded with the existing dependency graph.
- After adding the iOS camera dependency candidate, repeated `flutter pub get` failed with proxy/network restriction:
  - `Proxy failed to establish tunnel (403 Forbidden), uri=//pub.dev:443`
- Because dependency resolution could not be validated, real camera/HUD feature integration was intentionally not finalized in this commit.
- Current branch status for this task is therefore limited to iOS Info.plist compliance hardening and a documented dependency gate block.
