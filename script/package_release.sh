#!/usr/bin/env bash
set -euo pipefail

# Required for distribution: a "Developer ID Application" identity, not Apple Development.
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity.}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/AZpdf.app"
RELEASE_DIR="$ROOT_DIR/dist/release"
ENTITLEMENTS="$ROOT_DIR/Config/AZpdf.entitlements"

"$ROOT_DIR/script/build_and_run.sh" --bundle
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
