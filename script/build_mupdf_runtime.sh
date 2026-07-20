#!/usr/bin/env bash
set -euo pipefail

# Build only the static mutool helper needed for local image overlays.  MuPDF's
# bundled libraries avoid shipping Homebrew dylibs; crypto and GL viewer code
# are deliberately disabled because AZpdf does not use them.
: "${MUPDF_SOURCE_DIR:?Set MUPDF_SOURCE_DIR to an extracted MuPDF source tree.}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/dist/runtime/mutool}"
if [[ -z "${MUPDF_ARCHFLAGS+x}" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    MUPDF_ARCHFLAGS="-arch $(uname -m)"
  else
    MUPDF_ARCHFLAGS=""
  fi
fi
if [[ -z "${MUPDF_JOBS+x}" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    MUPDF_JOBS="$(nproc)"
  else
    MUPDF_JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
  fi
fi

[[ -f "$MUPDF_SOURCE_DIR/Makefile" ]] || { echo "MUPDF_SOURCE_DIR must contain a MuPDF Makefile" >&2; exit 2; }

make -C "$MUPDF_SOURCE_DIR" build=release clean
ARCHFLAGS="$MUPDF_ARCHFLAGS" make -C "$MUPDF_SOURCE_DIR" -j"$MUPDF_JOBS" build=release shared=no tesseract=no HAVE_GLUT=no

mkdir -p "$OUTPUT_DIR"
cp "$MUPDF_SOURCE_DIR/build/release/mutool" "$OUTPUT_DIR/mutool"
chmod +x "$OUTPUT_DIR/mutool"
"$ROOT_DIR/script/audit_runtime.sh" "$OUTPUT_DIR" mutool
version_output="$("$OUTPUT_DIR/mutool" --version 2>&1 || true)"
grep -q '^mutool version ' <<<"$version_output" || {
  echo "Built mutool did not report its version" >&2
  exit 1
}

echo "MuPDF runtime: $OUTPUT_DIR/mutool"
