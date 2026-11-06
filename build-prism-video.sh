#!/usr/bin/env bash
# Builds libprism_video.dylib into vendor/mpv/buildout.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$PROJECT_ROOT/vendor/mpv/buildout/libprism_video.dylib"
ARCH="${MPV_TARGET_ARCH:-$(uname -m)}"

clang -dynamiclib -fobjc-arc -fvisibility=hidden -O2 \
    -arch "$ARCH" -mmacosx-version-min="${MACOSX_DEPLOYMENT_TARGET:-13.0}" \
    -framework Cocoa -framework QuartzCore -framework Metal \
    -install_name @rpath/libprism_video.dylib \
    -o "$OUT" "$PROJECT_ROOT/overlay/prism_video/prism_video.m"
echo "Built $OUT"
