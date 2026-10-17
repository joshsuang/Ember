#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
MIN_MACOS="14.0"
APP="$ROOT/.build/Ember.app"
# Building inside a synchronized/file-provider workspace can attach Finder metadata before
# codesign runs. Build outside it, then stage a clean bundle and sign afterward.
BUILD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ember-build.XXXXXX")"
cleanup() { rm -rf "$BUILD_TMP"; }
trap cleanup EXIT
STAGED_APP="$BUILD_TMP/Ember.app"
mkdir -p "$STAGED_APP/Contents/MacOS"
xcrun swiftc \
  -sdk "$SDK" \
  -target "${ARCH}-apple-macosx${MIN_MACOS}" \
  -O \
  -module-name EmberStudy \
  "$ROOT"/Sources/EmberStudyApp/*.swift \
  -framework SwiftUI \
  -framework AppKit \
  -framework Combine \
  -o "$STAGED_APP/Contents/MacOS/Ember"
cat > "$STAGED_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Ember</string>
    <key>CFBundleIdentifier</key><string>app.ember.study</string>
    <key>CFBundleName</key><string>Ember</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Ember' "$STAGED_APP/Contents/Info.plist"
mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
ditto "$STAGED_APP" "$APP"
xattr -cr "$APP"
codesign --force --sign - --identifier app.ember.study "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP (ad-hoc signed; requires an Apple Development signing identity for CloudKit entitlements)"
