#!/usr/bin/env bash
#
# make-icon.sh - regenerate Twine's app icon from scripts/icon.svg.
# Renders a 1024 master, downsamples to every macOS size in the appiconset,
# and refreshes the README icon (assets/icon.png).
#
# Requires: rsvg-convert (brew install librsvg), sips (built in).
#
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="scripts/icon.svg"
MASTER="scripts/icon-1024.png"
ICO="Twine/Resources/Assets.xcassets/AppIcon.appiconset"

rsvg-convert -w 1024 -h 1024 "$SRC" -o "$MASTER"

# filename : pixel size
sizes=(
  "icon_16x16.png:16" "icon_16x16@2x.png:32"
  "icon_32x32.png:32" "icon_32x32@2x.png:64"
  "icon_128x128.png:128" "icon_128x128@2x.png:256"
  "icon_256x256.png:256" "icon_256x256@2x.png:512"
  "icon_512x512.png:512" "icon_512x512@2x.png:1024"
)
for entry in "${sizes[@]}"; do
  name="${entry%%:*}"; px="${entry##*:}"
  sips -z "$px" "$px" "$MASTER" --out "$ICO/$name" >/dev/null
done

sips -z 256 256 "$MASTER" --out assets/icon.png >/dev/null
echo "Icon regenerated from $SRC"
