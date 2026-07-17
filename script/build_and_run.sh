#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AZpdf"
BUNDLE_ID="org.azpdf.mac"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_MACOS="$APP_BUNDLE/Contents/MacOS"
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$(swift build --show-bin-path)/$APP_NAME" "$APP_MACOS/$APP_NAME"
mkdir -p "$APP_RESOURCES"
cp "$ROOT_DIR/Assets/AZpdf.icns" "$APP_RESOURCES/AZpdf.icns"
cp "$ROOT_DIR/Assets/donate-vietqr.jpg" "$APP_RESOURCES/donate-vietqr.jpg"
cp "$ROOT_DIR/Assets/mupdf_add_image.js" "$APP_RESOURCES/mupdf_add_image.js"
if [[ -n "${MUTOOL_RUNTIME_DIR:-}" ]]; then
  [[ -x "$MUTOOL_RUNTIME_DIR/mutool" ]] || { echo "MUTOOL_RUNTIME_DIR must contain executable mutool" >&2; exit 2; }
  mkdir -p "$APP_RESOURCES/Tools"
  cp -R "$MUTOOL_RUNTIME_DIR/." "$APP_RESOURCES/Tools/"
  chmod +x "$APP_RESOURCES/Tools/mutool"
fi
if [[ -n "${VERAPDF_RUNTIME_DIR:-}" ]]; then
  [[ -x "$VERAPDF_RUNTIME_DIR/verapdf" ]] || { echo "VERAPDF_RUNTIME_DIR must contain executable verapdf" >&2; exit 2; }
  mkdir -p "$APP_RESOURCES/Tools/veraPDF"
  cp -R "$VERAPDF_RUNTIME_DIR/." "$APP_RESOURCES/Tools/veraPDF/"
  chmod +x "$APP_RESOURCES/Tools/veraPDF/verapdf"
fi
if [[ -n "${PYHANKO_RUNTIME_DIR:-}" ]]; then
  [[ -x "$PYHANKO_RUNTIME_DIR/pyhanko" ]] || { echo "PYHANKO_RUNTIME_DIR must contain a self-contained executable pyhanko" >&2; exit 2; }
  mkdir -p "$APP_RESOURCES/Tools/pyhanko"
  cp -R "$PYHANKO_RUNTIME_DIR/." "$APP_RESOURCES/Tools/pyhanko/"
  chmod +x "$APP_RESOURCES/Tools/pyhanko/pyhanko"
fi
if [[ -n "${PDFSIG_RUNTIME_DIR:-}" ]]; then
  [[ -x "$PDFSIG_RUNTIME_DIR/pdfsig" ]] || { echo "PDFSIG_RUNTIME_DIR must contain executable pdfsig" >&2; exit 2; }
  mkdir -p "$APP_RESOURCES/Tools"
  cp -R "$PDFSIG_RUNTIME_DIR/." "$APP_RESOURCES/Tools/"
  chmod +x "$APP_RESOURCES/Tools/pdfsig"
fi
chmod +x "$APP_MACOS/$APP_NAME"

cat >"$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AZpdf.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

case "$MODE" in
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --debug|debug) lldb -- "$APP_MACOS/$APP_NAME" ;;
  --logs|logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  --bundle|bundle) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--bundle]" >&2; exit 2 ;;
esac
