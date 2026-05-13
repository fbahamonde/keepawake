#!/bin/bash
set -euo pipefail

APP="KeepAwake.app"
SRC_FILES=(src/*.swift)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -target arm64-apple-macos14 -O "${SRC_FILES[@]}" \
  -framework AppKit \
  -framework IOKit \
  -framework CoreWLAN \
  -framework CoreLocation \
  -framework ServiceManagement \
  -framework Security \
  -framework UserNotifications \
  -o "$APP/Contents/MacOS/KeepAwake"

codesign -s - --force --deep "$APP"

echo "Built $APP"
