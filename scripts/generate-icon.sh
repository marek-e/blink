#!/bin/sh
# Regenerates Blink/Resources/Assets.xcassets/AppIcon.appiconset from scripts/IconGenerator.
set -eu
cd "$(dirname "$0")/.."
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
swiftc -O scripts/IconGenerator/main.swift Blink/Sources/Support/BlinkGlyph.swift -o "$build_dir/generate-icon"
output="Blink/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$output"
"$build_dir/generate-icon" "$output"
