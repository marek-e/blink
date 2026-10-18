#!/bin/sh
# Builds and launches a Debug copy of Blink with a scratch configuration file, so manual testing
# never touches your real settings. Usage: scripts/run-debug.sh [scratch-dir]
set -eu
cd "$(dirname "$0")/.."
scratch="${1:-${TMPDIR:-/tmp}/blink-debug}"
mkdir -p "$scratch"
xcodebuild -quiet -project Blink.xcodeproj -scheme Blink -configuration Debug -derivedDataPath build/DerivedData build
pkill -x Blink 2>/dev/null || true
open -n build/DerivedData/Build/Products/Debug/Blink.app --args \
  -BlinkConfigurationPath "$scratch/configuration.json" \
  -BlinkSnapshotDirectory "$scratch/snapshots"
echo "Blink (Debug) running with settings in $scratch"
