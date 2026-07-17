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

# Finder metadata and quarantine/resource-fork xattrs make codesign reject an
# otherwise valid bundle. Build artifacts must be metadata-free before the
# inner-to-outer signing pass.
/bin/chmod -R u+w "$APP_BUNDLE"
/usr/bin/xattr -cr "$APP_BUNDLE"

# Copied OCR/Java data can retain an executable bit. codesign --deep treats
# such data as nested code and then rejects it because it has no signature.
# Keep the bit only for actual Mach-O executables and interpreter scripts.
while IFS= read -r -d '' candidate; do
  if /usr/bin/file "$candidate" | rg -q 'Mach-O'; then continue; fi
  if [[ "$(head -c 2 "$candidate" 2>/dev/null || true)" == '#!' ]]; then continue; fi
  /bin/chmod a-x "$candidate"
done < <(/usr/bin/find "$APP_BUNDLE/Contents" -type f \( -perm -100 -o -perm -010 -o -perm -001 \) -print0)

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
