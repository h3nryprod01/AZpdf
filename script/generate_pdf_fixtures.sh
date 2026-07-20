#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/Tests/Fixtures/source"
OUTPUT_DIR="${1:-$ROOT_DIR/Tests/Fixtures/generated}"
MUTOOL_BIN="${MUTOOL_BIN:-$(command -v mutool || true)}"

[[ -n "$MUTOOL_BIN" && -x "$MUTOOL_BIN" ]] || {
  echo "MuPDF mutool is required to generate fixtures." >&2
  exit 2
}

mkdir -p "$OUTPUT_DIR"
"$MUTOOL_BIN" create -o "$OUTPUT_DIR/basic.pdf" "$SOURCE_DIR/basic-page.txt"
"$MUTOOL_BIN" create -o "$OUTPUT_DIR/two-column.pdf" "$SOURCE_DIR/two-column-page.txt"
"$MUTOOL_BIN" create -o "$OUTPUT_DIR/rotated.pdf" "$SOURCE_DIR/rotated-page.txt"

echo "Generated PDF fixtures: $OUTPUT_DIR"
