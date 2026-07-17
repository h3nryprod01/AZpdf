#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <app-bundle> <signing-identity>" >&2
  exit 2
fi

APP_BUNDLE="$1"
SIGNING_IDENTITY="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTITLEMENTS="$ROOT_DIR/Config/AZpdf.entitlements"

[[ -d "$APP_BUNDLE" ]] || { echo "Signing failed: app bundle does not exist: $APP_BUNDLE" >&2; exit 1; }
[[ -f "$ENTITLEMENTS" ]] || { echo "Signing failed: entitlements file does not exist: $ENTITLEMENTS" >&2; exit 1; }

# Sign every embedded Mach-O file first.  This includes command-line helpers and
# their private dylibs, if any.  The bundle itself must be signed last so its
# resource seal includes the already-signed nested code.
while IFS= read -r -d '' candidate; do
  if /usr/bin/file "$candidate" | rg -q 'Mach-O'; then
    /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$candidate"
  fi
done < <(/usr/bin/find "$APP_BUNDLE/Contents" -type f -print0)

/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
  --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
