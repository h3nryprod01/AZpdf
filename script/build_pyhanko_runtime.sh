#!/usr/bin/env bash
set -euo pipefail

# Build a one-file, relocatable pyHanko CLI for Contents/Helpers/pyhanko.
# Use a pinned Python environment containing pyhanko-cli and PyInstaller.
: "${PYHANKO_PYTHON:?Set PYHANKO_PYTHON to the Python executable in the pinned pyHanko build environment.}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/dist/runtime/pyhanko}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/azpdf-pyhanko-build.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

"$PYHANKO_PYTHON" -m PyInstaller \
  --noconfirm \
  --clean \
  --onefile \
  --name pyhanko \
  --distpath "$WORK_DIR/dist" \
  --workpath "$WORK_DIR/work" \
  --specpath "$WORK_DIR/spec" \
  "$ROOT_DIR/script/pyhanko_entry.py"

mkdir -p "$OUTPUT_DIR"
cp "$WORK_DIR/dist/pyhanko" "$OUTPUT_DIR/pyhanko"
chmod +x "$OUTPUT_DIR/pyhanko"
"$ROOT_DIR/script/audit_runtime.sh" "$OUTPUT_DIR" pyhanko
"$OUTPUT_DIR/pyhanko" --version
echo "Built pyHanko runtime: $OUTPUT_DIR/pyhanko"
