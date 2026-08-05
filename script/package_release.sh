#!/usr/bin/env bash
set -euo pipefail

# Required for distribution: a "Developer ID Application" identity, not Apple Development.
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity.}"
: "${MUTOOL_RUNTIME_DIR:?Set MUTOOL_RUNTIME_DIR to a self-contained, redistributable MuPDF runtime directory.}"
: "${PYHANKO_RUNTIME_DIR:?Set PYHANKO_RUNTIME_DIR to a self-contained, redistributable pyHanko runtime directory.}"

# veraPDF and OCRmyPDF are droppable, but never SILENTLY: an unset variable used to be a
# hard error, and turning that into "just skip it" would be the same fail-open shape this
# repo already got burned by twice — a forgotten export would ship a release missing a
# runtime with nothing going red. So omitting one is opt-in and must be named:
#
#   AZPDF_OMIT_RUNTIMES="verapdf ocrmypdf" ./script/package_release.sh
#
# Measured reason this exists (2026-08-05): the veraPDF runtime is 413 MB, of which 380 MB
# is the bundled JRE — 9x the size of veraPDF itself — to serve PDF/A validation alone.
# OCRmyPDF needs Tesseract/Ghostscript/qpdf built from source (docs/MACOS_RELEASE.md forbids
# shipping Homebrew builds). The app already treats both as runtime-optional.
AZPDF_OMIT_RUNTIMES="${AZPDF_OMIT_RUNTIMES:-}"
omitted() { [[ " $AZPDF_OMIT_RUNTIMES " == *" $1 "* ]]; }
for pair in "verapdf:VERAPDF_RUNTIME_DIR" "ocrmypdf:OCRMY_PDF_RUNTIME_DIR"; do
  name="${pair%%:*}"; var="${pair#*:}"
  if omitted "$name"; then
    [[ -z "${!var:-}" ]] || { echo "$var is set but '$name' is listed in AZPDF_OMIT_RUNTIMES; pick one." >&2; exit 2; }
    echo "package_release: shipping WITHOUT the $name runtime (AZPDF_OMIT_RUNTIMES)." >&2
  else
    [[ -n "${!var:-}" ]] || { echo "Set $var, or list '$name' in AZPDF_OMIT_RUNTIMES to ship without it." >&2; exit 2; }
  fi
done
export SWIFT_CONFIGURATION="${SWIFT_CONFIGURATION:-release}"
# Release builds go into a neutral scratch directory: SwiftPM embeds the
# absolute build path in the binary (Bundle.module's fallback), so building
# from a home directory would ship the developer's username and folder layout
# in an artifact that strangers download.
export SWIFT_SCRATCH_PATH="${SWIFT_SCRATCH_PATH:-/private/tmp/azpdf-release-build}"

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
omitted verapdf || [[ -x "$APP_BUNDLE/Contents/Resources/Helpers/veraPDF/verapdf" ]] || {
  echo "Release packaging failed: bundled veraPDF runtime is missing." >&2
  exit 1
}
[[ -x "$APP_BUNDLE/Contents/Resources/Helpers/pyhanko/pyhanko" ]] || {
  echo "Release packaging failed: bundled pyHanko runtime is missing." >&2
  exit 1
}
omitted ocrmypdf || [[ -x "$APP_BUNDLE/Contents/Resources/Helpers/ocrmypdf/ocrmypdf" ]] || {
  echo "Release packaging failed: bundled OCRmyPDF runtime is missing." >&2
  exit 1
}
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers" "mutool"
omitted verapdf || "$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers/veraPDF" "verapdf"
"$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers/pyhanko" "pyhanko"
omitted ocrmypdf || "$ROOT_DIR/script/audit_runtime.sh" "$APP_BUNDLE/Contents/Resources/Helpers/ocrmypdf" "ocrmypdf"
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
