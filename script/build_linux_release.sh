#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "build_linux_release.sh chỉ chạy trên Linux." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
SWIFT_BIN="${SWIFT_BIN:-swift}"
SWIFT_CONTAINER_IMAGE="${SWIFT_CONTAINER_IMAGE:-swift:6.3.3}"
MUTOOL_BIN="${MUTOOL_BIN:-}"
OCRMY_PDF_RUNTIME_DIR="${OCRMY_PDF_RUNTIME_DIR:-}"
PYHANKO_RUNTIME_DIR="${PYHANKO_RUNTIME_DIR:-}"
BUILD_PATH="${AZPDF_LINUX_SWIFT_BUILD_PATH:-$ROOT/.build-linux-static}"
SHELL_DIR="$ROOT/Shell/azpdf_desktop"
BUNDLE="$SHELL_DIR/build/linux/x64/release/bundle"
RESOURCE_BUNDLE_NAME="AZpdf_AZpdfMuPDF.resources"
RESOURCE_BUNDLE="$BUILD_PATH/release/$RESOURCE_BUNDLE_NAME"

if [[ -z "$MUTOOL_BIN" || ! -x "$MUTOOL_BIN" ]]; then
  echo "Đặt MUTOOL_BIN tới mutool 1.28.0 đã qua script/audit_runtime.sh." >&2
  exit 1
fi

swift_build_arguments=(
  build
  -c release
  --build-path "$BUILD_PATH"
  -Xswiftc -static-stdlib
  --product azpdf-engine
)

if command -v "$SWIFT_BIN" >/dev/null 2>&1; then
  "$SWIFT_BIN" package --build-path "$BUILD_PATH" clean
  "$SWIFT_BIN" "${swift_build_arguments[@]}"
elif command -v docker >/dev/null 2>&1; then
  docker run --rm \
    -e HOME=/tmp \
    -v "$ROOT:$ROOT" \
    -w "$ROOT" \
    "$SWIFT_CONTAINER_IMAGE" \
    swift package --build-path "$BUILD_PATH" clean
  docker run --rm \
    -e HOME=/tmp \
    -v "$ROOT:$ROOT" \
    -w "$ROOT" \
    "$SWIFT_CONTAINER_IMAGE" \
    swift "${swift_build_arguments[@]}"
else
  echo "Cần Swift 6 hoặc Docker để build azpdf-engine." >&2
  exit 1
fi

(
  cd "$SHELL_DIR"
  "$FLUTTER_BIN" pub get
  "$FLUTTER_BIN" analyze
  "$FLUTTER_BIN" test
  "$FLUTTER_BIN" build linux --release
)

install -m 755 "$BUILD_PATH/release/azpdf-engine" "$BUNDLE/azpdf-engine"
strip "$BUNDLE/azpdf-engine"
install -m 755 "$MUTOOL_BIN" "$BUNDLE/mutool"
rm -rf "$BUNDLE/runtime/ocrmypdf" "$BUNDLE/runtime/pyhanko"
if [[ -n "$OCRMY_PDF_RUNTIME_DIR" ]]; then
  if [[ ! -x "$OCRMY_PDF_RUNTIME_DIR/ocrmypdf" ]]; then
    echo "OCRMY_PDF_RUNTIME_DIR phải chứa executable ocrmypdf." >&2
    exit 1
  fi
  mkdir -p "$BUNDLE/runtime/ocrmypdf"
  cp -R "$OCRMY_PDF_RUNTIME_DIR/." "$BUNDLE/runtime/ocrmypdf/"
fi
if [[ -n "$PYHANKO_RUNTIME_DIR" ]]; then
  if [[ ! -x "$PYHANKO_RUNTIME_DIR/pyhanko" ]]; then
    echo "PYHANKO_RUNTIME_DIR phải chứa executable pyhanko portable." >&2
    exit 1
  fi
  mkdir -p "$BUNDLE/runtime/pyhanko"
  cp -R "$PYHANKO_RUNTIME_DIR/." "$BUNDLE/runtime/pyhanko/"
fi
if [[ ! -f "$RESOURCE_BUNDLE/Resources/azpdf_annotations.js" ]]; then
  echo "Thiếu SwiftPM annotation resource bundle: $RESOURCE_BUNDLE" >&2
  exit 1
fi
mkdir -p "$BUNDLE/$RESOURCE_BUNDLE_NAME/Resources"
install -m 644 \
  "$RESOURCE_BUNDLE/Resources/azpdf_annotations.js" \
  "$BUNDLE/$RESOURCE_BUNDLE_NAME/Resources/azpdf_annotations.js"

# `grep` POSIX, KHÔNG phải `rg`, và xử lý exit-status tường minh. Ba lệnh `rg` trong file này
# đã hỏng suốt trên máy không cài ripgrep — đo trên runner GitHub 2026-08-15:
#   · hai lệnh dưới đây: `rg: command not found` ⇒ ống trả khác 0 ⇒ điều kiện SAI ⇒ rơi thẳng
#     xuống dòng "pass". Hai audit dependency này CHƯA TỪNG chạy trong CI.
#   · lệnh health bên dưới: cùng lý do, nhưng ở nhánh `if !` nên biến kết quả ĐÚNG thành đỏ.
# Máy dev có ripgrep nên dựng tay luôn qua, và không ai thấy. Đây là lần THỨ BA lớp lỗi này
# cắn dự án (xem decisions.md 2026-07-31: hai security gate "pass" nhiều tháng mà chưa quét gì).
check_missing_libs() {
  local name="$1" path="$2" out status
  out="$(ldd "$path" 2>&1)"
  set +e
  printf '%s\n' "$out" | grep -q 'not found'
  status=$?
  set -e
  case "$status" in
    0) echo "$name còn dependency bị thiếu." >&2; printf '%s\n' "$out" >&2; exit 1 ;;
    1) ;;
    *) echo "Không kiểm được dependency của $name: grep thoát $status." >&2; exit 1 ;;
  esac
}
check_missing_libs azpdf-engine "$BUNDLE/azpdf-engine"
check_missing_libs mutool "$BUNDLE/mutool"

if [[ -x "$BUNDLE/runtime/ocrmypdf/ocrmypdf" ]]; then
  "$ROOT/script/audit_runtime.sh" "$BUNDLE/runtime/ocrmypdf" ocrmypdf
fi

if [[ -x "$BUNDLE/runtime/pyhanko/pyhanko" ]]; then
  "$ROOT/script/audit_runtime.sh" "$BUNDLE/runtime/pyhanko" pyhanko
fi

# Một helper cho mọi lần soi output JSON. Dùng grep POSIX và phân biệt "không khớp" (exit 1)
# với "không chạy được" (exit khác) — vì đó chính là chỗ `rg` đã lừa: thiếu binary trả 127, mà
# `if ! rg ...` đọc 127 thành "không khớp" rồi báo hỏng trên một kết quả hoàn toàn đúng.
require_json() {
  local label="$1" pattern="$2" payload="$3" status
  set +e
  printf '%s\n' "$payload" | grep -q "$pattern"
  status=$?
  set -e
  case "$status" in
    0) printf '%s\n' "$payload" ;;   # in ra để phần tổng kết cuối file thấy được, không cần biến rời
    1) echo "$label thất bại: $payload" >&2; exit 1 ;;
    *) echo "Không kiểm được $label: grep thoát $status. Output: $payload" >&2; exit 1 ;;
  esac
}

require_json "Engine health check" '"ok":true' "$($BUNDLE/azpdf-engine health)"

if [[ -x "$BUNDLE/runtime/ocrmypdf/ocrmypdf" ]]; then
  require_json "OCR health check" '"ok":true' "$($BUNDLE/azpdf-engine ocr-health)"
fi

if [[ -x "$BUNDLE/runtime/pyhanko/pyhanko" ]]; then
  require_json "PAdES health check" '"ok":true' "$($BUNDLE/azpdf-engine signature-health)"
fi

smoke_directory="$(mktemp -d)"
trap 'rm -rf "$smoke_directory"' EXIT
MUTOOL_BIN="$BUNDLE/mutool" "$ROOT/script/generate_pdf_fixtures.sh" "$smoke_directory"
require_json "Engine annotation resource check" '"annotations":\[\]' \
  "$($BUNDLE/azpdf-engine annotations --document "$smoke_directory/basic.pdf" --page 0)"

if [[ -x "$BUNDLE/runtime/ocrmypdf/ocrmypdf" && \
      -x "$BUNDLE/runtime/pyhanko/pyhanko" ]]; then
  sbom="$SHELL_DIR/build/linux/x64/release/AZpdf-Linux-SBOM.spdx"
  "$ROOT/script/generate_linux_sbom.sh" "$BUNDLE" "$sbom"
fi

echo "AZpdf Linux bundle: $BUNDLE"
# health/ocr-health/signature-health đã được require_json in ra ngay lúc kiểm, nên ở đây
# không còn biến nào để echo — ba dòng cũ tham chiếu $health sau khi refactor xoá biến đó,
# và `set -u` biến chúng thành "unbound variable" đúng ở bước cuối cùng của cả job.
if [[ -n "${sbom:-}" ]]; then echo "SBOM: $sbom"; fi
