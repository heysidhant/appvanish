#!/bin/zsh
# Archives the sandboxed App Store edition and exports a signed package.
#
#   scripts/make-appstore.sh            → dist/AppStore/AppVanish.pkg
#   UPLOAD=1 scripts/make-appstore.sh   → also uploads to App Store Connect
#
# Needs the Apple Developer account signed in to Xcode. The upload also needs the app record in
# App Store Connect. Increase the build number for every upload: BUILD_NUMBER=2 scripts/make-appstore.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEAM="${TEAM_ID:-RUCQNP5F6L}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DERIVED="$ROOT/build/AppStoreDerivedData"
ARCHIVE="$ROOT/build/AppVanish-AppStore.xcarchive"
OUT="$ROOT/dist/AppStore"
cd "$ROOT"

rm -rf "$ARCHIVE" "$OUT"
mkdir -p "$OUT"

echo "▸ Archiving Release (arm64 + x86_64), build $BUILD_NUMBER…"
xcodebuild -project AppVanish.xcodeproj -scheme AppVanish -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  -xcconfig Config/Leftovers.xcconfig \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="$TEAM" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive -quiet

echo "▸ Exporting signed package…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT" \
  -exportOptionsPlist "$ROOT/Config/ExportOptions-AppStore.plist" \
  -allowProvisioningUpdates

echo "▸ Package:"
ls -lh "$OUT"/*.pkg

if [[ "${UPLOAD:-0}" == 1 ]]; then
  echo "▸ Uploading to App Store Connect…"
  OPTIONS=$(mktemp -t ExportOptions)
  trap 'rm -f "$OPTIONS"' EXIT
  sed 's#<string>export</string>#<string>upload</string>#' "$ROOT/Config/ExportOptions-AppStore.plist" > "$OPTIONS"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT" \
    -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates
fi

echo "▸ Done"
