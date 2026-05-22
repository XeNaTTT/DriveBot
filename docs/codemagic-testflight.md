# Codemagic iOS TestFlight deployment (no local Mac)

This guide explains how to ship this Flutter app to **TestFlight** using **Codemagic cloud macOS builders**, so you do not need a Mac locally.

## 1) Create an Apple Developer account

1. Sign in with your Apple ID at [developer.apple.com](https://developer.apple.com/).
2. Enroll in the Apple Developer Program (paid).
3. Wait until your account is fully active.

## 2) Create the Bundle ID

1. Open Apple Developer > Certificates, Identifiers & Profiles.
2. Go to **Identifiers** > **+**.
3. Register an **App ID**.
4. Set an explicit bundle ID (example: `com.yourcompany.driveassistantar`).
5. Keep this value for Codemagic as `BUNDLE_ID`.

## 3) Create the app in App Store Connect

1. Open [App Store Connect](https://appstoreconnect.apple.com/).
2. Go to **Apps** > **+** > **New App**.
3. Choose iOS, app name, primary language, bundle ID, SKU.
4. Save.

## 4) Create an App Store Connect API key

1. App Store Connect > **Users and Access** > **Keys**.
2. Click **+** to create a new API key.
3. Give it a name and role (usually App Manager or Admin for CI upload).
4. Download the `.p8` key once.
5. Record:
   - **Issuer ID** → `APP_STORE_CONNECT_ISSUER_ID`
   - **Key ID** → `APP_STORE_CONNECT_KEY_IDENTIFIER`
   - **Private key content** from `.p8` → `APP_STORE_CONNECT_PRIVATE_KEY`

## 5) Connect GitHub repository to Codemagic

1. Sign in at [codemagic.io](https://codemagic.io/) with GitHub.
2. Add this repository.
3. Ensure `codemagic.yaml` is detected from the repo root.

## 6) Add required environment variables/secrets in Codemagic

Create secure variables (or groups) in Codemagic with these names:

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `CERTIFICATE_PRIVATE_KEY`
- `BUNDLE_ID`
- `APPLE_TEAM_ID`

Notes:
- Paste `APP_STORE_CONNECT_PRIVATE_KEY` as the full `.p8` key body including BEGIN/END lines.
- `CERTIFICATE_PRIVATE_KEY` is the private key associated with your iOS distribution certificate (if using manual signing asset setup).

## 7) Configure iOS code signing in Codemagic

Use Codemagic **iOS code signing** settings to add:

1. Apple Developer integration (or API key auth).
2. Distribution certificate/private key.
3. App Store provisioning profile for your bundle ID.

The workflow uses:
- `distribution_type: app_store`
- `bundle_identifier: $BUNDLE_ID`

## 8) Run your first build

1. Start workflow: **ios-testflight**.
2. Codemagic runs:
   - `flutter pub get`
   - `flutter analyze`
   - `flutter test`
   - `flutter build ipa --release`
3. On success, an IPA is uploaded to App Store Connect/TestFlight.

## 9) Find the build in App Store Connect > TestFlight

1. Open App Store Connect > your app > **TestFlight**.
2. Wait for Apple processing to complete.
3. Confirm the new build appears.

## 10) Add an internal tester

1. In TestFlight, open **Internal Testing**.
2. Add users from your App Store Connect team.
3. Assign the build.

## 11) Install on iPhone via TestFlight

1. Install the TestFlight app from the App Store on iPhone.
2. Open invitation link or accept inside TestFlight.
3. Install the build and test.

## Current repository caveat

This repository currently has limited iOS scaffolding checked in (only `ios/Runner/Info.plist` plus CI files added here). Before the first successful TestFlight upload, ensure the full Flutter iOS project files (`ios/Runner.xcodeproj`, `ios/Runner.xcworkspace`, `ios/Flutter/*`) are present by running `flutter create --platforms=ios .` in an environment with Flutter installed, then commit those generated iOS files.
