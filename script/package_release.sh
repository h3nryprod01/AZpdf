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

"$ROOT_DIR/script/build_and_run.sh" --bundle
[[ -x "$APP_BUNDLE/Contents/Helpers/mutool" ]] || {
  echo "Release packaging failed: bundled MuPDF runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Helpers/veraPDF/verapdf" ]] || {
  echo "Release packaging failed: bundled veraPDF runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Helpers/pyhanko/pyhanko" ]] || {
  echo "Release packaging failed: bundled pyHanko runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Helpers/pdfsig" ]] || {
  echo "Release packaging failed: bundled pdfsig runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Helpers/ocrmypdf/ocrmypdf" ]] || {
  echo "Release packaging failed: bundled OCRmyPDF runtime is missing." >&2
  exit 1
}
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Helpers" "mutool"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Helpers/veraPDF" "verapdf"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Helpers/pyhanko" "pyhanko"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Helpers" "pdfsig"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Helpers/ocrmypdf" "ocrmypdf"
"$ROOT_DIR/script/sign_bundle.sh" "$APP_BUNDLE" "$SIGNING_IDENTITY"
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
