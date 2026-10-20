#!/bin/bash
# Bungkus dist/Suhu Mac.app menjadi DMG. Argumen: versi (mis. 0.2.0).
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?pakai: make-dmg.sh <versi>}"
app="dist/Suhu Mac.app"
dmg="dist/SuhuMac-${version}.dmg"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Suhu Mac.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname "Suhu Mac" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
printf 'DMG siap: %s\n' "$dmg"
