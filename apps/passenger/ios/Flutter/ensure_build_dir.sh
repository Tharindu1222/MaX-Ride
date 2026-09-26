#!/bin/sh
# Keep Flutter/Xcode outputs off iCloud Desktop. File Provider xattrs make
# Xcode 26 codesign fail with "resource fork ... detritus not allowed".
set -e
APP_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
CACHE_DIR="${HOME}/Library/Caches/max-ride-passenger-ios-build"
BUILD_DIR="$APP_DIR/build"
mkdir -p "$CACHE_DIR"
if [ -L "$BUILD_DIR" ]; then
  exit 0
fi
if [ -e "$BUILD_DIR" ]; then
  rm -rf "$BUILD_DIR"
fi
ln -s "$CACHE_DIR" "$BUILD_DIR"
