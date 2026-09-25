#!/bin/zsh
# Builds "Side by Side.app" next to this script.
set -e
cd "$(dirname "$0")"
APP="Side by Side.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# App icon: icon.svg -> AppIcon.icns
TMP=$(mktemp -d)
qlmanage -t -s 1024 -o "$TMP" icon.svg >/dev/null 2>&1
ICONSET="$TMP/AppIcon.iconset"; mkdir "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.svg.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.svg.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"
swiftc -O -parse-as-library main.swift -o "$APP/Contents/MacOS/SideBySide"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Side by Side</string>
  <key>CFBundleExecutable</key><string>SideBySide</string>
  <key>CFBundleIdentifier</key><string>com.andrewneuwirth.sidebyside</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
