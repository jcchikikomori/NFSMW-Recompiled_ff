#!/usr/bin/env bash
# Builds the launcher-only AppImage (native Qt launcher + Qt 6 + extract-xiso).
#
# The recompiled game executable is NOT part of this package: producing it
# needs the copyrighted game XEX and the ReXGlue codegen, so it can only be
# built locally (see packaging/appimage/README.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/app/build}"
APPDIR="${APPDIR:-$BUILD_DIR/AppDir}"
ARCH="${ARCH:-$(uname -m)}"
OUTPUT="${OUTPUT:-$BUILD_DIR/NFSMW-Launcher-${ARCH}.AppImage}"

LAUNCHER_BIN="${LAUNCHER_BIN:-$BUILD_DIR/launcher-linux/nfsmw_launcher}"

LINUXDEPLOY="${LINUXDEPLOY:-$(command -v linuxdeploy || true)}"
APPIMAGETOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"

if [[ ! -f "$LAUNCHER_BIN" ]]; then
  echo "Missing launcher artifact: $LAUNCHER_BIN" >&2
  echo "Build it first with: cmake --build app/build --target nfsmw_launcher" >&2
  exit 1
fi
if [[ -z "$LINUXDEPLOY" || ! -x "$LINUXDEPLOY" ]]; then
  echo "Set LINUXDEPLOY to a linuxdeploy executable." >&2
  exit 1
fi
if [[ -z "$APPIMAGETOOL" || ! -x "$APPIMAGETOOL" ]]; then
  echo "Set APPIMAGETOOL to an appimagetool executable." >&2
  exit 1
fi
if ! command -v linuxdeploy-plugin-qt >/dev/null 2>&1; then
  echo "linuxdeploy-plugin-qt must be available in PATH." >&2
  exit 1
fi
# The plugin looks for a plain "qmake" before "qmake6"; on distributions that
# only ship Qt 6 the binary is qmake6, so pass it explicitly instead of letting
# the plugin guess (it would otherwise bundle Qt 5 paths).
QMAKE="${QMAKE:-$(command -v qmake6 || command -v qmake || true)}"
if [[ -z "$QMAKE" || ! -x "$QMAKE" ]]; then
  echo "Qt 6 qmake was not found; set QMAKE to qmake6." >&2
  exit 1
fi
export QMAKE

EXTRACT_XISO_BIN="${EXTRACT_XISO_BIN:-}"
EXTRACT_XISO_LICENSE=""
if [[ -z "$EXTRACT_XISO_BIN" ]]; then
  EXTRACT_SOURCE="$BUILD_DIR/appimage-tools/extract-xiso"
  EXTRACT_BUILD="$EXTRACT_SOURCE/build-${ARCH}"
  EXTRACT_COMMIT="b72e5b60d598ec6df80534cda19cdcd4361aa18c"
  if [[ ! -d "$EXTRACT_SOURCE/.git" ]]; then
    mkdir -p "$(dirname "$EXTRACT_SOURCE")"
    git clone https://github.com/XboxDev/extract-xiso.git "$EXTRACT_SOURCE"
  fi
  git -C "$EXTRACT_SOURCE" fetch --depth 1 origin "$EXTRACT_COMMIT"
  git -C "$EXTRACT_SOURCE" checkout --detach "$EXTRACT_COMMIT"
  cmake -S "$EXTRACT_SOURCE" -B "$EXTRACT_BUILD" \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "$EXTRACT_BUILD" --parallel
  EXTRACT_XISO_BIN="$EXTRACT_BUILD/extract-xiso"
  EXTRACT_XISO_LICENSE="$EXTRACT_SOURCE/LICENSE.TXT"
fi
if [[ ! -x "$EXTRACT_XISO_BIN" ]]; then
  echo "extract-xiso executable not found: $EXTRACT_XISO_BIN" >&2
  exit 1
fi

rm -rf "$APPDIR"
install -d \
  "$APPDIR/usr/bin" \
  "$APPDIR/usr/lib" \
  "$APPDIR/usr/libexec" \
  "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/scalable/apps" \
  "$APPDIR/usr/share/licenses/extract-xiso"

install -m755 "$LAUNCHER_BIN" "$APPDIR/usr/bin/nfsmw_launcher"
install -m755 "$EXTRACT_XISO_BIN" "$APPDIR/usr/libexec/extract-xiso"
install -m644 "$ROOT/packaging/appimage/nfsmw.desktop" \
  "$APPDIR/usr/share/applications/nfsmw.desktop"
install -m644 "$ROOT/packaging/appimage/nfsmw.svg" \
  "$APPDIR/usr/share/icons/hicolor/scalable/apps/nfsmw.svg"
if [[ -n "$EXTRACT_XISO_LICENSE" ]]; then
  install -m644 "$EXTRACT_XISO_LICENSE" \
    "$APPDIR/usr/share/licenses/extract-xiso/LICENSE.TXT"
fi

"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/nfsmw_launcher" \
  --desktop-file "$APPDIR/usr/share/applications/nfsmw.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/scalable/apps/nfsmw.svg" \
  --plugin qt \
  --custom-apprun "$ROOT/packaging/appimage/AppRun"

# The custom AppRun already forces QT_QPA_PLATFORM=xcb, so only the xcb
# platform plugin deployed by linuxdeploy-plugin-qt is needed.
"$APPIMAGETOOL" "$APPDIR" "$OUTPUT"
echo "Created: $OUTPUT"
