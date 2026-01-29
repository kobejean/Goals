#!/bin/bash
# Generate channel icons from custom SVG artwork
# Requires ImageMagick (brew install imagemagick)

set -e
cd "$(dirname "$0")"

SVG_SOURCE="../../Graphics/wii-icon.svg"
BG_COLOR="#1A1A2E"

if [ ! -f "$SVG_SOURCE" ]; then
    echo "Error: Custom icon not found at $SVG_SOURCE"
    exit 1
fi

if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick not found. Install with: brew install imagemagick"
    exit 1
fi

echo "Generating Wii Fit Sync channel assets from custom SVG..."

# icon.png - 128x48 for Homebrew Channel (transparent background)
magick "$SVG_SOURCE" -resize 128x48 -background transparent -gravity center -extent 128x48 icon.png

# icon_large.png - 128x128 for Wii Menu channel icon (dark background)
magick "$SVG_SOURCE" -resize 128x48 -background "$BG_COLOR" -gravity center -extent 128x128 icon_large.png

# banner.png - 608x456 for channel banner when selected (dark background)
magick "$SVG_SOURCE" -resize 400x150 -background "$BG_COLOR" -gravity center -extent 608x456 banner.png

# Copy icon to parent directory for HBC
cp icon.png ../icon.png

echo ""
echo "Generated:"
ls -la *.png
echo ""
echo "Also copied icon.png to wii-app/ for Homebrew Channel"
