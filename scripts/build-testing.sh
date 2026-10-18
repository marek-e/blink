#!/bin/sh
# Builds an optimized, universal copy of Blink that, like Debug builds, accepts
# -BlinkConfigurationPath and -BlinkSnapshotDirectory. Used for performance runs and for testing
# the Intel slice under Rosetta. Output: build/Testing/Build/Products/Release/Blink.app
set -eu
cd "$(dirname "$0")/.."
xcodebuild -quiet -project Blink.xcodeproj -scheme Blink -configuration Release \
  -derivedDataPath build/Testing \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=BLINK_TESTING build
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$lsregister" -u build/Testing/Build/Products/Release/Blink.app 2>/dev/null || true
echo build/Testing/Build/Products/Release/Blink.app
