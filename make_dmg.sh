#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-NewNet}"
APP_PATH="${APP_PATH:-/Users/nn/Desktop/internetManager/NewNet/build/Release/${APP_NAME}.app}"
BUILD_DIR="${BUILD_DIR:-/Users/nn/Desktop/internetManager/NewNet/build}"
STAGING_DIR="${STAGING_DIR:-/tmp/${APP_NAME}-dmg-staging}"
DMG_PATH="${DMG_PATH:-${BUILD_DIR}/${APP_NAME}.dmg}"
TMP_RW_DMG="/tmp/${APP_NAME}-rw.dmg"
TMP_DMG="/tmp/${APP_NAME}.dmg"
INSTALLER_ICON_PNG="${INSTALLER_ICON_PNG:-/Users/nn/Desktop/internetManager/NewNet/installer_icon.png}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at: $APP_PATH"
  echo "Build the macOS app first, or set APP_PATH to your .app."
  exit 1
fi

rm -rf "$STAGING_DIR" "$TMP_RW_DMG" "$TMP_DMG"
mkdir -p "$STAGING_DIR" "$BUILD_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TMP_RW_DMG"

if [[ -f "$INSTALLER_ICON_PNG" ]]; then
  MOUNT_DIR="$(mktemp -d /tmp/${APP_NAME}-mount-XXXXXX)"
  TMP_ICNS="/tmp/${APP_NAME}.icns"
  rm -f "$TMP_ICNS"
  sips -s format icns "$INSTALLER_ICON_PNG" --out "$TMP_ICNS" >/dev/null
  hdiutil attach "$TMP_RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet
  cp "$TMP_ICNS" "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_DIR"
  hdiutil detach "$MOUNT_DIR" -quiet
  rm -rf "$MOUNT_DIR" "$TMP_ICNS"
fi

hdiutil convert "$TMP_RW_DMG" -format UDZO -o "$TMP_DMG" -ov
mv "$TMP_DMG" "$DMG_PATH"
rm -f "$TMP_RW_DMG"

if [[ -f "$INSTALLER_ICON_PNG" ]]; then
  TMP_RSRC="/tmp/${APP_NAME}.rsrc"
  rm -f "$TMP_RSRC"
  sips -i "$INSTALLER_ICON_PNG" >/dev/null
  DeRez -only icns "$INSTALLER_ICON_PNG" > "$TMP_RSRC"
  Rez -append "$TMP_RSRC" -o "$DMG_PATH"
  SetFile -a C "$DMG_PATH"
  rm -f "$TMP_RSRC"
fi

echo "DMG created at: $DMG_PATH"
