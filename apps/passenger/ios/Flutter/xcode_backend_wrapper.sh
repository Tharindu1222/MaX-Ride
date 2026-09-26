#!/bin/sh
# Puts a codesign shim ahead of /usr/bin/codesign for Flutter's iOS assemble
# steps. See codesign_shim/codesign.
#
# Also keeps build/ off iCloud Desktop. File Provider xattrs on Desktop make
# Xcode 26 codesign fail with "resource fork, Finder information, or similar
# detritus not allowed".
set -e
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
CACHE_DIR="${HOME}/Library/Caches/max-ride-passenger-ios-build"
BUILD_DIR="$APP_DIR/build"
mkdir -p "$CACHE_DIR"
if [ ! -e "$BUILD_DIR" ]; then
  ln -s "$CACHE_DIR" "$BUILD_DIR"
fi
export PATH="$SCRIPT_DIR/codesign_shim:$PATH"
exec /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@"
