#!/usr/bin/env bash
# Build a distributable BatteryMonitor.app and a .dmg for a GitHub release.
#
#   ./scripts/build-release.sh [version]   # default version: 1.0
#
# Default: ad-hoc signed ("Sign to Run Locally") — runs locally but is NOT
# notarized, so downloaders must clear quarantine (see README → Releases).
#
# Developer ID + notarization (requires Apple Developer Program membership and a
# "Developer ID Application" certificate in the keychain):
#
#   TEAM_ID=XXXXXXXXXX NOTARY_PROFILE=bm-notary ./scripts/build-release.sh 1.2.0
#
# where the notarytool keychain profile is created once via:
#   xcrun notarytool store-credentials bm-notary \
#     --apple-id you@example.com --team-id XXXXXXXXXX --password <app-specific-pw>
#
# Requires: Xcode command-line tools + xcodegen (`brew install xcodegen`).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

command -v xcodegen >/dev/null || { echo "Missing xcodegen — run: brew install xcodegen"; exit 1; }

echo "▸ Generating Xcode project…"
xcodegen generate

echo "▸ Building Release…"
rm -rf build dist
if [[ -n "$TEAM_ID" ]]; then
  xcodebuild -project BatteryMonitor.xcodeproj -scheme BatteryMonitor \
    -configuration Release -derivedDataPath build \
    CODE_SIGN_IDENTITY="Developer ID Application" CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" OTHER_CODE_SIGN_FLAGS="--timestamp" \
    | tail -2
else
  xcodebuild -project BatteryMonitor.xcodeproj -scheme BatteryMonitor \
    -configuration Release -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
    | tail -2
fi

APP="build/Build/Products/Release/BatteryMonitor.app"
codesign --verify --verbose=1 "$APP"

echo "▸ Packaging DMG…"
mkdir -p dist/stage
cp -R "$APP" dist/stage/
ln -s /Applications dist/stage/Applications
hdiutil create -volname "Battery Monitor" -srcfolder dist/stage \
  -ov -format UDZO "dist/BatteryMonitor-${VERSION}.dmg" >/dev/null
rm -rf dist/stage

if [[ -n "$TEAM_ID" && -n "$NOTARY_PROFILE" ]]; then
  echo "▸ Notarizing DMG (this waits on Apple)…"
  xcrun notarytool submit "dist/BatteryMonitor-${VERSION}.dmg" \
    --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "dist/BatteryMonitor-${VERSION}.dmg"
  echo "✓ Notarized + stapled"
elif [[ -n "$TEAM_ID" ]]; then
  echo "⚠ Signed with Developer ID but NOT notarized (set NOTARY_PROFILE to notarize)."
fi

echo "✓ dist/BatteryMonitor-${VERSION}.dmg"
echo
echo "Publish to GitHub:"
echo "  gh release create v${VERSION} dist/BatteryMonitor-${VERSION}.dmg \\"
echo "    --title \"Battery Monitor ${VERSION}\" --notes-file RELEASE_NOTES.md"
