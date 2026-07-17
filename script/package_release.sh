#!/usr/bin/env bash
set -euo pipefail

# Required for distribution: a "Developer ID Application" identity, not Apple Development.
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity.}"
: "${MUTOOL_RUNTIME_DIR:?Set MUTOOL_RUNTIME_DIR to a self-contained, redistributable MuPDF runtime directory.}"
: "${VERAPDF_RUNTIME_DIR:?Set VERAPDF_RUNTIME_DIR to a self-contained veraPDF runtime directory.}"
: "${PYHANKO_RUNTIME_DIR:?Set PYHANKO_RUNTIME_DIR to a self-contained, redistributable pyHanko runtime directory.}"
: "${PDFSIG_RUNTIME_DIR:?Set PDFSIG_RUNTIME_DIR to a self-contained, redistributable pdfsig runtime directory.}"
: "${OCRMY_PDF_RUNTIME_DIR:?Set OCRMY_PDF_RUNTIME_DIR to a self-contained, redistributable OCRmyPDF runtime directory.}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/AZpdf.app"
RELEASE_DIR="$ROOT_DIR/dist/release"
ENTITLEMENTS="$ROOT_DIR/Config/AZpdf.entitlements"

"$ROOT_DIR/script/build_and_run.sh" --bundle
[[ -x "$APP_BUNDLE/Contents/Resources/Tools/mutool" ]] || {
  echo "Release packaging failed: bundled MuPDF runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Tools/veraPDF/verapdf" ]] || {
  echo "Release packaging failed: bundled veraPDF runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Tools/pyhanko/pyhanko" ]] || {
  echo "Release packaging failed: bundled pyHanko runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Tools/pdfsig" ]] || {
  echo "Release packaging failed: bundled pdfsig runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Tools/ocrmypdf/ocrmypdf" ]] || {
  echo "Release packaging failed: bundled OCRmyPDF runtime is missing." >&2
  exit 1
}
/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/sbin/spctl -a -vv "$APP_BUNDLE"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_DIR/AZpdf-macOS.zip"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  /usr/bin/xcrun notarytool submit "$RELEASE_DIR/AZpdf-macOS.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  /usr/bin/xcrun stapler staple "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

echo "Release archive: $RELEASE_DIR/AZpdf-macOS.zip"
