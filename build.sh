#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
MIN_MACOS="14.0"
APP="$ROOT/.build/Ember.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc \
  -sdk "$SDK" \
  -target "${ARCH}-apple-macosx${MIN_MACOS}" \
  -O \
  -module-name EmberStudy \
  "$ROOT"/Sources/EmberStudyApp/*.swift \
  -framework SwiftUI \
  -framework AppKit \
  -framework Combine \
  -o "$APP/Contents/MacOS/Ember"
cat > "$APP/Contents/Info.plist" <<'PLIST'
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
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Ember' "$APP/Contents/Info.plist"
echo "Built $APP"
