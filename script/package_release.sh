#!/usr/bin/env bash
set -euo pipefail

# Required for distribution: a "Developer ID Application" identity, not Apple Development.
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity.}"
: "${MUTOOL_RUNTIME_DIR:?Set MUTOOL_RUNTIME_DIR to a self-contained, redistributable MuPDF runtime directory.}"
: "${VERAPDF_RUNTIME_DIR:?Set VERAPDF_RUNTIME_DIR to a self-contained veraPDF runtime directory.}"
: "${PYHANKO_RUNTIME_DIR:?Set PYHANKO_RUNTIME_DIR to a self-contained, redistributable pyHanko runtime directory.}"
: "${OCRMY_PDF_RUNTIME_DIR:?Set OCRMY_PDF_RUNTIME_DIR to a self-contained, redistributable OCRmyPDF runtime directory.}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/AZpdf.app"
RELEASE_DIR="$ROOT_DIR/dist/release"
SIGNING_DIR="$(/usr/bin/mktemp -d /private/tmp/azpdf-release.XXXXXX)"
SIGNED_APP_BUNDLE="$SIGNING_DIR/AZpdf.app"

# macOS may attach com.apple.provenance to artifacts built under Documents.
# Sign a metadata-free staging copy so codesign's resource seal is stable.
trap '/bin/rm -rf "$SIGNING_DIR"' EXIT

"$ROOT_DIR/script/build_and_run.sh" --bundle
 /usr/bin/ditto --noextattr --norsrc "$APP_BUNDLE" "$SIGNED_APP_BUNDLE"
APP_BUNDLE="$SIGNED_APP_BUNDLE"
[[ -x "$APP_BUNDLE/Contents/Resources/Helpers/mutool" ]] || {
  echo "Release packaging failed: bundled MuPDF runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Helpers/veraPDF/verapdf" ]] || {
  echo "Release packaging failed: bundled veraPDF runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Helpers/pyhanko/pyhanko" ]] || {
  echo "Release packaging failed: bundled pyHanko runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Helpers/ocrmypdf/ocrmypdf" ]] || {
  echo "Release packaging failed: bundled OCRmyPDF runtime is missing." >&2
  exit 1
}
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers" "mutool"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers/veraPDF" "verapdf"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers/pyhanko" "pyhanko"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers/ocrmypdf" "ocrmypdf"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$APP_BUNDLE/Contents/Resources/THIRD_PARTY_NOTICES.md"
"$ROOT_DIR/script/generate_sbom.sh" "$APP_BUNDLE" "$APP_BUNDLE/Contents/Resources/SBOM.spdx"
"$ROOT_DIR/script/sign_bundle.sh" "$APP_BUNDLE" "$SIGNING_IDENTITY"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
cp "$APP_BUNDLE/Contents/Resources/SBOM.spdx" "$RELEASE_DIR/AZpdf-macOS.spdx"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_DIR/AZpdf-macOS.zip"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  /usr/bin/xcrun notarytool submit "$RELEASE_DIR/AZpdf-macOS.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  /usr/bin/xcrun stapler staple "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  /usr/sbin/spctl -a -vv "$APP_BUNDLE"
  # Rebuild after stapling so the downloadable ZIP also works offline.
  /bin/rm -f "$RELEASE_DIR/AZpdf-macOS.zip"
  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_DIR/AZpdf-macOS.zip"
fi

echo "Release archive: $RELEASE_DIR/AZpdf-macOS.zip"
