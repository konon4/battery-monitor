#!/usr/bin/env bash
# Build a distributable BatteryMonitor.app and a .dmg for a GitHub release.
#
#   ./scripts/build-release.sh [version]   # default version: 1.0
#
# Requires: Xcode command-line tools + xcodegen (`brew install xcodegen`).
# The app is ad-hoc signed ("Sign to Run Locally") — it runs locally but is NOT
# notarized, so downloaders must clear quarantine (see README → Releases).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0}"

command -v xcodegen >/dev/null || { echo "Missing xcodegen — run: brew install xcodegen"; exit 1; }

echo "▸ Generating Xcode project…"
xcodegen generate

echo "▸ Building Release…"
rm -rf build dist
xcodebuild -project BatteryMonitor.xcodeproj -scheme BatteryMonitor \
  -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
  | tail -2

APP="build/Build/Products/Release/BatteryMonitor.app"
codesign --verify --verbose=1 "$APP"

echo "▸ Packaging DMG…"
mkdir -p dist/stage
cp -R "$APP" dist/stage/
ln -s /Applications dist/stage/Applications
hdiutil create -volname "Battery Monitor" -srcfolder dist/stage \
  -ov -format UDZO "dist/BatteryMonitor-${VERSION}.dmg" >/dev/null
rm -rf dist/stage

echo "✓ dist/BatteryMonitor-${VERSION}.dmg"
echo
echo "Publish to GitHub:"
echo "  gh release create v${VERSION} dist/BatteryMonitor-${VERSION}.dmg \\"
echo "    --title \"Battery Monitor ${VERSION}\" --notes-file RELEASE_NOTES.md"
