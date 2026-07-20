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

if ldd "$BUNDLE/azpdf-engine" | rg -q 'not found'; then
  echo "azpdf-engine còn dependency bị thiếu." >&2
  ldd "$BUNDLE/azpdf-engine" >&2
  exit 1
fi

if ldd "$BUNDLE/mutool" | rg -q 'not found'; then
  echo "mutool còn dependency bị thiếu." >&2
  ldd "$BUNDLE/mutool" >&2
  exit 1
fi

if [[ -x "$BUNDLE/runtime/ocrmypdf/ocrmypdf" ]]; then
  "$ROOT/script/audit_runtime.sh" "$BUNDLE/runtime/ocrmypdf" ocrmypdf
fi

if [[ -x "$BUNDLE/runtime/pyhanko/pyhanko" ]]; then
  "$ROOT/script/audit_runtime.sh" "$BUNDLE/runtime/pyhanko" pyhanko
fi

health="$($BUNDLE/azpdf-engine health)"
if ! rg -q '"ok":true' <<<"$health"; then
  echo "Engine health check thất bại: $health" >&2
  exit 1
fi

if [[ -x "$BUNDLE/runtime/ocrmypdf/ocrmypdf" ]]; then
  ocr_health="$($BUNDLE/azpdf-engine ocr-health)"
  if ! rg -q '"ok":true' <<<"$ocr_health"; then
    echo "OCR health check thất bại: $ocr_health" >&2
    exit 1
  fi
fi

if [[ -x "$BUNDLE/runtime/pyhanko/pyhanko" ]]; then
  signature_health="$($BUNDLE/azpdf-engine signature-health)"
  if ! rg -q '"ok":true' <<<"$signature_health"; then
    echo "PAdES health check thất bại: $signature_health" >&2
    exit 1
  fi
fi

smoke_directory="$(mktemp -d)"
trap 'rm -rf "$smoke_directory"' EXIT
MUTOOL_BIN="$BUNDLE/mutool" "$ROOT/script/generate_pdf_fixtures.sh" "$smoke_directory"
annotations="$($BUNDLE/azpdf-engine annotations --document "$smoke_directory/basic.pdf" --page 0)"
if ! rg -q '"annotations":\[\]' <<<"$annotations"; then
  echo "Engine annotation resource check thất bại: $annotations" >&2
  exit 1
fi

if [[ -x "$BUNDLE/runtime/ocrmypdf/ocrmypdf" && \
      -x "$BUNDLE/runtime/pyhanko/pyhanko" ]]; then
  sbom="$SHELL_DIR/build/linux/x64/release/AZpdf-Linux-SBOM.spdx"
  "$ROOT/script/generate_linux_sbom.sh" "$BUNDLE" "$sbom"
fi

echo "AZpdf Linux bundle: $BUNDLE"
echo "$health"
if [[ -n "${ocr_health:-}" ]]; then echo "$ocr_health"; fi
if [[ -n "${signature_health:-}" ]]; then echo "$signature_health"; fi
if [[ -n "${sbom:-}" ]]; then echo "SBOM: $sbom"; fi
