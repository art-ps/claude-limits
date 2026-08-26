#!/bin/bash
# Builds ClaudeLimits.app — a menu bar only (LSUIElement) bundle.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(tr -d "[:space:]" < VERSION)

swift run ClaudeLimits --selftest
swift build -c release

swift Tools/make-icon.swift .build
iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns

APP="ClaudeLimits.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ClaudeLimits "$APP/Contents/MacOS/ClaudeLimits"
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ClaudeLimits</string>
    <key>CFBundleDisplayName</key>     <string>Claude Limits</string>
    <key>CFBundleIdentifier</key>      <string>in.pisarev.ClaudeLimits</string>
    <key>CFBundleExecutable</key>      <string>ClaudeLimits</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "built $PWD/$APP ($VERSION)"
