#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
swift scripts/make-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o Resources/AppIcon.icns
cp .build/AppIcon.iconset/icon_512x512@2x.png Resources/AppIcon.png
app_dir="$PWD/dist/Suhu Mac.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/SuhuMacbook" "$app_dir/Contents/MacOS/SuhuMacbook"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Resources/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app_dir"
printf 'Aplikasi siap: %s\n' "$app_dir"
