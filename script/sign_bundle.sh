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
# grep POSIX + phân biệt "không phải Mach-O" với "không kiểm được". Trước đây dùng `rg`, và
# thiếu ripgrep thì exit 127 bị đọc thành "không khớp" ở CẢ HAI vòng lặp dưới, theo hai hướng
# hỏng khác nhau:
#   · vòng 1 (`if ...; then continue; fi`): KHÔNG bỏ qua Mach-O nữa ⇒ đi gỡ bit thực thi của
#     chính các binary ⇒ bundle hỏng.
#   · vòng 2: không ký gì cả ⇒ bundle không chữ ký, và lỗi chỉ lộ ra ở bước verify sau đó.
# Máy dev có ripgrep nên chưa ai gặp. Nay không kiểm được thì DỪNG, không đoán.
is_macho() {
  local out status
  out="$(/usr/bin/file "$1" 2>&1)"
  set +e
  printf '%s\n' "$out" | grep -q 'Mach-O'
  status=$?
  set -e
  case "$status" in
    0) return 0 ;;
    1) return 1 ;;
    *) echo "Không kiểm được kiểu file của $1: grep thoát $status" >&2; exit 1 ;;
  esac
}

while IFS= read -r -d '' candidate; do
  if is_macho "$candidate"; then continue; fi
  if [[ "$(head -c 2 "$candidate" 2>/dev/null || true)" == '#!' ]]; then continue; fi
  /bin/chmod a-x "$candidate"
done < <(/usr/bin/find "$APP_BUNDLE/Contents" -type f \( -perm -100 -o -perm -010 -o -perm -001 \) -print0)

# Sign every embedded Mach-O file first.  This includes command-line helpers and
# their private dylibs, if any.  The bundle itself must be signed last so its
# resource seal includes the already-signed nested code.
while IFS= read -r -d '' candidate; do
  if is_macho "$candidate"; then
    /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$candidate"
  fi
done < <(/usr/bin/find "$APP_BUNDLE/Contents" -type f -print0)

/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
  --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
