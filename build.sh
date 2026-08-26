#!/bin/bash
# Builds ClaudeLimits.app — a menu bar only (LSUIElement) bundle.
set -euo pipefail
cd "$(dirname "$0")"

swift run ClaudeLimits --selftest
swift build -c release

APP="ClaudeLimits.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClaudeLimits "$APP/Contents/MacOS/ClaudeLimits"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ClaudeLimits</string>
    <key>CFBundleDisplayName</key>     <string>Claude Limits</string>
    <key>CFBundleIdentifier</key>      <string>in.pisarev.ClaudeLimits</string>
    <key>CFBundleExecutable</key>      <string>ClaudeLimits</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "built $PWD/$APP"
