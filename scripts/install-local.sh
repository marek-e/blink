#!/bin/sh
# Builds a Release copy of Blink signed for this Mac only (ad-hoc) and installs it in /Applications.
# For distribution to other Macs, use scripts/release.sh instead.
set -eu
cd "$(dirname "$0")/.."
destination="${1:-/Applications}"

swift test --package-path Packages/BlinkCore --quiet
xcodebuild -quiet -project Blink.xcodeproj -scheme Blink -configuration Release -derivedDataPath build/DerivedData build

if pgrep -xq Blink; then
  echo "Quitting the running copy of Blink (links still waiting in it are discarded)…"
  pkill -x Blink || true
  sleep 1
fi
rm -rf "$destination/Blink.app"
ditto build/DerivedData/Build/Products/Release/Blink.app "$destination/Blink.app"
# Make the installed copy the only one macOS offers as a browser: forget copies in the build folder.
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
for built in build/*/Build/Products/*/Blink.app; do
  [ -d "$built" ] && "$lsregister" -u "$built" 2>/dev/null || true
done
"$lsregister" -f "$destination/Blink.app"
echo "Installed $destination/Blink.app"
open "$destination/Blink.app"
