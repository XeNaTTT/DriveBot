#!/usr/bin/env bash
set -euo pipefail

logs="$CM_BUILD_DIR/build/native-logs"
mkdir -p "$logs"
udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"].get("com.apple.CoreSimulator.SimRuntime.iOS-27-2", [])
matches = [d for d in devices if d["name"] == "iPhone 17" and d["isAvailable"]]
if not matches:
    sys.exit("iPhone 17 / iOS 27.2 simulator unavailable")
print(next((d for d in matches if d["state"] == "Booted"), matches[0])["udid"])
')

# Boot the same device the test host will use while Xcode builds for it.
(time xcrun simctl bootstatus "$udid" -b) > "$logs/simulator-boot.log" 2>&1 &
boot_pid=$!
trap 'kill "$boot_pid" 2>/dev/null || true' EXIT
xcode=(xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner
  -configuration Debug -destination "platform=iOS Simulator,id=$udid"
  -derivedDataPath "$CM_BUILD_DIR/build/gameplay-derived-data"
  COMPILATION_CACHE_ENABLE_CACHING=YES CODE_SIGNING_ALLOWED=NO)

(time "${xcode[@]}" -showBuildTimingSummary build-for-testing) 2>&1 | tee "$logs/gameplay-build.log"
wait "$boot_pid" || { cat "$logs/simulator-boot.log"; exit 1; }
trap - EXIT
cat "$logs/simulator-boot.log"
(time "${xcode[@]}" -parallel-testing-enabled NO -resultBundlePath "$logs/gameplay.xcresult" test-without-building) 2>&1 | tee "$logs/gameplay.log"
