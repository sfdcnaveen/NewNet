#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
DMG_NAME="NewNet"
DMG_PATH="$BUILD_DIR/${DMG_NAME}.dmg"
DMG_TEMP="$BUILD_DIR/${DMG_NAME}.sparseimage"
STAGING_DIR="$BUILD_DIR/dmg-stage"
BACKGROUND_PATH="$BUILD_DIR/dmg_background.png"
ICON_PNG="$ROOT_DIR/installer_icon.png"
ICONSET_DIR="$BUILD_DIR/volume.iconset"
ICON_ICNS="$BUILD_DIR/.VolumeIcon.icns"
FFMPEG_TAG="b6.1.1"
FFMPEG_BASE_URL="https://github.com/eugeneware/ffmpeg-static/releases/download/${FFMPEG_TAG}"
FFMPEG_ARM_URL="${FFMPEG_BASE_URL}/ffmpeg-darwin-arm64"
FFMPEG_X64_URL="${FFMPEG_BASE_URL}/ffmpeg-darwin-x64"

mkdir -p "$BUILD_DIR"

echo "Building Release app (unsigned)..."
xcodebuild \
  -scheme NewNet \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -destination "generic/platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

APP_PATH="$DERIVED_DATA/Build/Products/Release/NewNet.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app not found at: $APP_PATH"
  exit 1
fi

echo "Bundling ffmpeg binaries..."
RESOURCE_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCE_DIR"
if [[ ! -x "$RESOURCE_DIR/ffmpeg-arm64" ]]; then
  curl -L -f "$FFMPEG_ARM_URL" -o "$RESOURCE_DIR/ffmpeg-arm64"
  chmod +x "$RESOURCE_DIR/ffmpeg-arm64"
fi
if [[ ! -x "$RESOURCE_DIR/ffmpeg-x64" ]]; then
  curl -L -f "$FFMPEG_X64_URL" -o "$RESOURCE_DIR/ffmpeg-x64"
  chmod +x "$RESOURCE_DIR/ffmpeg-x64"
fi

echo "Ad-hoc signing the app bundle to prevent 'damaged' errors..."
codesign --force --deep --sign - "$APP_PATH"

echo "Preparing staging folder..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Generating DMG background..."
swift "$ROOT_DIR/scripts/generate_dmg_assets.swift" "$BACKGROUND_PATH"

if [[ -f "$ICON_PNG" ]]; then
  echo "Generating volume icon..."
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
fi

echo "Creating writable DMG..."
rm -f "$DMG_TEMP" "$DMG_PATH"
hdiutil create -size 220m -fs HFS+ -volname "$DMG_NAME" -type SPARSE "$DMG_TEMP"

ATTACH_INFO=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP")
DEVICE=$(echo "$ATTACH_INFO" | awk '/^\/dev\// {print $1; exit}')
VOLUME=$(echo "$ATTACH_INFO" | awk '/\/Volumes\// {print $3; exit}')

if [[ -z "$DEVICE" || -z "$VOLUME" ]]; then
  echo "Failed to mount DMG."
  exit 1
fi

mkdir -p "$VOLUME/.background"
cp -R "$STAGING_DIR/"* "$VOLUME/"
cp "$BACKGROUND_PATH" "$VOLUME/.background/dmg_background.png"

if [[ -f "$ICON_ICNS" ]]; then
  cp "$ICON_ICNS" "$VOLUME/.VolumeIcon.icns"
  SETFILE=$(xcrun -f SetFile 2>/dev/null || true)
  if [[ -n "$SETFILE" ]]; then
    "$SETFILE" -a C "$VOLUME/.VolumeIcon.icns"
    "$SETFILE" -a C "$VOLUME"
  fi
fi

echo "Setting Finder layout..."
osascript <<EOF
tell application "Finder"
  tell disk "$DMG_NAME"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 200, 860, 620}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to POSIX file "$VOLUME/.background/dmg_background.png"
    delay 1
    try
      set position of item "$DMG_NAME.app" of container window to {200, 270}
    end try
    try
      set position of item "Applications" of container window to {480, 270}
    end try
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
bless --folder "$VOLUME" --openfolder "$VOLUME" || true
hdiutil detach "$DEVICE"

echo "Converting to compressed DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$DMG_TEMP"

echo "DMG created at: $DMG_PATH"
MOUNT_DIR="$BUILD_DIR/dmg-mount"
