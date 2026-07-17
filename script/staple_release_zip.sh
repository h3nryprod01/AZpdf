#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <AZpdf-macOS.zip>" >&2
  exit 2
fi

ARCHIVE="$1"
[[ -f "$ARCHIVE" ]] || { echo "Release archive does not exist: $ARCHIVE" >&2; exit 1; }

# Use ditto for both directions. unzip may materialise macOS extended
# attributes as ._* files, invalidating the sealed resource list after staple.
STAGE_DIR="$(/usr/bin/mktemp -d /private/tmp/azpdf-staple.XXXXXX)"
STAGED_APP="$STAGE_DIR/AZpdf.app"
TEMP_ARCHIVE="${ARCHIVE%.zip}.stapled.zip"
trap '/bin/rm -rf "$STAGE_DIR" "$TEMP_ARCHIVE"' EXIT

/usr/bin/ditto -x -k "$ARCHIVE" "$STAGE_DIR"
[[ -d "$STAGED_APP" ]] || { echo "Release archive does not contain AZpdf.app." >&2; exit 1; }

if /usr/bin/xcrun stapler validate "$STAGED_APP" >/dev/null 2>&1; then
  echo "A stapled ticket is already present."
else
  /usr/bin/xcrun stapler staple "$STAGED_APP"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
/usr/sbin/spctl -a -vv "$STAGED_APP"
/usr/bin/xcrun stapler validate "$STAGED_APP"

/usr/bin/ditto -c -k --keepParent "$STAGED_APP" "$TEMP_ARCHIVE"
/bin/mv "$TEMP_ARCHIVE" "$ARCHIVE"
/usr/bin/shasum -a 256 "$ARCHIVE"
echo "Stapled release archive: $ARCHIVE"
