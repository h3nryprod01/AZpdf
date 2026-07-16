#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-dist/AZpdf.app}"
/usr/bin/codesign -dvvv --entitlements :- "$APP_BUNDLE"
/usr/bin/codesign -dvvv "$APP_BUNDLE" 2>&1 | /usr/bin/grep -q 'Authority=Developer ID Application:' || {
  echo "Release verification failed: the bundle is not signed with Developer ID Application." >&2
  exit 1
}
/usr/bin/codesign -d --entitlements :- "$APP_BUNDLE" 2>/dev/null | /usr/bin/grep -q '<key>com.apple.security.get-task-allow</key>' && {
  echo "Release verification failed: get-task-allow must not be present." >&2
  exit 1
}
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/sbin/spctl -a -vv "$APP_BUNDLE"
