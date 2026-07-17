#!/usr/bin/env bash
set -euo pipefail

: "${VERAPDF_SOURCE_DIR:?Set VERAPDF_SOURCE_DIR to the veraPDF libexec directory.}"
: "${JAVA_HOME:?Set JAVA_HOME to the JRE/JDK Contents/Home directory.}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/dist/runtime/veraPDF}"

[[ -x "$VERAPDF_SOURCE_DIR/verapdf" ]] || { echo "VERAPDF_SOURCE_DIR must contain executable verapdf" >&2; exit 2; }
[[ -x "$JAVA_HOME/bin/java" ]] || { echo "JAVA_HOME must contain executable bin/java" >&2; exit 2; }

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$VERAPDF_SOURCE_DIR/." "$OUTPUT_DIR/verapdf-app"
cp -R "$JAVA_HOME/." "$OUTPUT_DIR/jre"
cp "$ROOT_DIR/script/verapdf_wrapper.sh" "$OUTPUT_DIR/verapdf"
chmod +x "$OUTPUT_DIR/verapdf"

while IFS= read -r -d '' candidate; do
  file_type="$(file -b "$candidate")"
  [[ "$file_type" == *Mach-O* ]] || continue

  # Homebrew builds OpenJDK with absolute install names.  Replace those names
  # with the JDK's existing local @rpath layout after it has been copied.
  while IFS= read -r dependency; do
    [[ "$dependency" == "$JAVA_HOME"/* ]] || continue
    /usr/bin/install_name_tool -change "$dependency" "@rpath/$(basename "$dependency")" "$candidate"
  done < <(otool -L "$candidate" | tail -n +2 | awk '{print $1}')

  library_id="$(otool -D "$candidate" 2>/dev/null | tail -n +2 | head -n 1 || true)"
  if [[ "$library_id" == "$JAVA_HOME"/* ]]; then
    /usr/bin/install_name_tool -id "@rpath/$(basename "$library_id")" "$candidate"
  fi
done < <(find "$OUTPUT_DIR/jre" -type f -print0)

"$ROOT_DIR/script/audit_runtime.sh" "$OUTPUT_DIR" verapdf
"$OUTPUT_DIR/verapdf" --version

echo "veraPDF runtime: $OUTPUT_DIR"
