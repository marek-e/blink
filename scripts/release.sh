#!/bin/sh
# Builds a Developer ID-signed, notarized, stapled Blink release in dist/.
#
# Requires, in the environment:
#   DEVELOPER_ID_APPLICATION  e.g. "Developer ID Application: Jane Doe (TEAMID1234)", or its SHA-1 hash
#   NOTARY_PROFILE            a keychain profile created with:
#                             xcrun notarytool store-credentials <profile> --apple-id … --team-id …
# Optional:
#   NOTARY_KEYCHAIN           keychain holding the notarytool profile (CI uses a temporary one)
#   CODESIGN_KEYCHAIN         keychain holding the signing identity, if it isn't in the search list
#   SKIP_NOTARIZATION=1       sign only (for a dry run before credentials exist)
#
# Dry run without any certificate: DEVELOPER_ID_APPLICATION=- SKIP_NOTARIZATION=1 scripts/release.sh
# signs ad-hoc (no secure timestamp), which exercises every step except notarization.
set -eu
cd "$(dirname "$0")/.."

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity}"
if [ "${SKIP_NOTARIZATION:-0}" != 1 ]; then
  : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile, or SKIP_NOTARIZATION=1}"
fi

version=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
build=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\(.*\)"/\1/p' project.yml)
revision=$(git rev-parse --short HEAD)
sign_flags="--timestamp"
if [ "$DEVELOPER_ID_APPLICATION" = "-" ]; then
  if [ "${SKIP_NOTARIZATION:-0}" != 1 ]; then
    echo "Ad-hoc signing (-) can't be notarized; set SKIP_NOTARIZATION=1 for a dry run." >&2
    exit 1
  fi
  sign_flags=""
fi
if [ -n "${CODESIGN_KEYCHAIN:-}" ]; then
  sign_flags="$sign_flags --keychain $CODESIGN_KEYCHAIN"
fi
archive=build/Blink.xcarchive
rm -rf "$archive" dist
mkdir -p dist

echo "==> Testing"
swift test --package-path Packages/BlinkCore --quiet

echo "==> Archiving Blink $version ($build) at $revision"
# Archive unsigned, then sign explicitly. Blink is a single executable with no nested code, so one
# codesign call covers it, and signing doesn't depend on Xcode's certificate matching.
xcodebuild -quiet -project Blink.xcodeproj -scheme Blink -configuration Release \
  -archivePath "$archive" archive CODE_SIGNING_ALLOWED=NO

app=dist/Blink.app
ditto "$archive/Products/Applications/Blink.app" "$app"

echo "==> Signing"
# shellcheck disable=SC2086 # sign_flags holds separate arguments
codesign --force --options runtime $sign_flags \
  --entitlements Blink/Resources/Blink.entitlements \
  --sign "$DEVELOPER_ID_APPLICATION" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -d --verbose=2 "$app" 2>&1 | grep -E 'Authority|TeamIdentifier|flags'

notarize() {
  if [ -n "${NOTARY_KEYCHAIN:-}" ]; then
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --keychain "$NOTARY_KEYCHAIN" --wait
  else
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
  fi
}

if [ "${SKIP_NOTARIZATION:-0}" != 1 ]; then
  echo "==> Notarizing app"
  ditto -c -k --keepParent "$app" dist/Blink-notarize.zip
  notarize dist/Blink-notarize.zip
  rm dist/Blink-notarize.zip
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose=2 "$app"
fi

echo "==> Packaging"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Blink.app"
ln -s /Applications "$staging/Applications"
dmg="dist/Blink-$version.dmg"
hdiutil create -quiet -volname "Blink $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
# shellcheck disable=SC2086 # sign_flags holds separate arguments
codesign $sign_flags --sign "$DEVELOPER_ID_APPLICATION" "$dmg"
if [ "${SKIP_NOTARIZATION:-0}" != 1 ]; then
  notarize "$dmg"
  xcrun stapler staple "$dmg"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi
ditto -c -k --keepParent "$app" "dist/Blink-$version.zip"

(cd dist && shasum -a 256 "Blink-$version.dmg" "Blink-$version.zip" > SHA256SUMS.txt)
echo "$revision" > dist/REVISION.txt
echo "==> Done: dist/Blink-$version.dmg, dist/Blink-$version.zip"
cat dist/SHA256SUMS.txt
