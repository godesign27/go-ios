#!/usr/bin/env bash
# Builds Go and uploads it to TestFlight in one step.
# Uses the Apple account signed in to Xcode (Xcode > Settings > Accounts).
# Run from anywhere:  ./scripts/testflight.sh
set -euo pipefail

cd "$(dirname "$0")/.."

TEAM_ID="TTM6RL99QG"            # GO design, Inc
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/GoLauncher.xcarchive"
# Every upload needs a new, higher build number; a timestamp always is.
BUILD_NUMBER="$(date +%Y%m%d%H%M)"

echo "==> Getting the latest code"
git pull --ff-only

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "==> Installing XcodeGen"
  brew install xcodegen
fi

echo "==> Generating the Xcode project"
xcodegen

echo "==> Archiving build $BUILD_NUMBER (a few minutes)"
rm -rf "$ARCHIVE" "$BUILD_DIR/export"
mkdir -p "$BUILD_DIR"
xcodebuild \
  -project GoLauncher.xcodeproj \
  -scheme GoLauncher \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive

echo "==> Uploading to App Store Connect"
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$BUILD_DIR/export" \
  -allowProvisioningUpdates

echo
echo "Uploaded build $BUILD_NUMBER."
echo "It shows up in App Store Connect > GO Launcher > TestFlight in about 5-30 minutes."
