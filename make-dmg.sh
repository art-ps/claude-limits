#!/bin/bash
# Builds ClaudeLimits.app and wraps it in a distributable .dmg.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

APP="ClaudeLimits.app"
VERSION=$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)
DMG="ClaudeLimits-$VERSION.dmg"
STAGING=".build/dmg"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Claude Limits" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "built $PWD/$DMG"
