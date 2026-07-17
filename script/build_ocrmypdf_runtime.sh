#!/usr/bin/env bash
set -euo pipefail

# Produces a relocatable OCR runtime for AZpdf. The Python CLI is frozen with
# PyInstaller; native OCR tools and their non-system dylibs are copied beside
# it and rewritten to use @loader_path. This avoids shipping a Homebrew
# dependency graph in the released application.
: "${OCRMY_PDF_PYTHON:?Set OCRMY_PDF_PYTHON to Python with ocrmypdf and PyInstaller installed.}"
: "${TESSERACT_BIN:?Set TESSERACT_BIN to the Tesseract executable.}"
: "${GHOSTSCRIPT_BIN:?Set GHOSTSCRIPT_BIN to the Ghostscript (gs) executable.}"
: "${QPDF_BIN:?Set QPDF_BIN to the qpdf executable.}"
: "${TESSDATA_DIR:?Set TESSDATA_DIR to a directory containing eng.traineddata and vie.traineddata.}"
: "${GHOSTSCRIPT_RESOURCE_DIR:?Set GHOSTSCRIPT_RESOURCE_DIR to the Ghostscript Resource directory.}"
# Colon-separated roots that contain dylibs referenced as @rpath by the
# supplied native tools. Source builds should set this explicitly.
DYLIB_SEARCH_DIRS="${DYLIB_SEARCH_DIRS:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/dist/runtime/ocrmypdf}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/.build/ocrmypdf-runtime}"

for tool in "$OCRMY_PDF_PYTHON" "$TESSERACT_BIN" "$GHOSTSCRIPT_BIN" "$QPDF_BIN"; do
  [[ -x "$tool" ]] || { echo "Missing executable: $tool" >&2; exit 2; }
done
for language in eng vie; do
  [[ -f "$TESSDATA_DIR/$language.traineddata" ]] || { echo "Missing $language.traineddata in TESSDATA_DIR" >&2; exit 2; }
done
[[ -f "$TESSDATA_DIR/configs/hocr" ]] || { echo "TESSDATA_DIR must contain configs/hocr" >&2; exit 2; }
[[ -d "$GHOSTSCRIPT_RESOURCE_DIR/Init" ]] || { echo "GHOSTSCRIPT_RESOURCE_DIR must contain Init/" >&2; exit 2; }
"$OCRMY_PDF_PYTHON" -c 'import ocrmypdf, PyInstaller' >/dev/null

rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR/bin" "$OUTPUT_DIR/lib" "$OUTPUT_DIR/tessdata" "$OUTPUT_DIR/ghostscript"
ENTRYPOINT=$("$OCRMY_PDF_PYTHON" -c 'import ocrmypdf, pathlib; print(pathlib.Path(ocrmypdf.__file__).with_name("__main__.py"))')
"$OCRMY_PDF_PYTHON" -m PyInstaller --noconfirm --clean --onefile --name ocrmypdf-bin \
  --distpath "$BUILD_DIR/dist" --workpath "$BUILD_DIR/work" --specpath "$BUILD_DIR/spec" \
  --collect-all ocrmypdf --collect-submodules ocrmypdf "$ENTRYPOINT"
cp "$BUILD_DIR/dist/ocrmypdf-bin" "$OUTPUT_DIR/ocrmypdf-bin"
cp "$TESSERACT_BIN" "$OUTPUT_DIR/bin/tesseract"
cp "$GHOSTSCRIPT_BIN" "$OUTPUT_DIR/bin/gs"
cp "$QPDF_BIN" "$OUTPUT_DIR/bin/qpdf"
cp "$TESSDATA_DIR/eng.traineddata" "$TESSDATA_DIR/vie.traineddata" "$OUTPUT_DIR/tessdata/"
[[ -f "$TESSDATA_DIR/osd.traineddata" ]] && cp "$TESSDATA_DIR/osd.traineddata" "$OUTPUT_DIR/tessdata/" || true
cp -R "$TESSDATA_DIR/configs" "$OUTPUT_DIR/tessdata/"
cp -R "$GHOSTSCRIPT_RESOURCE_DIR/." "$OUTPUT_DIR/ghostscript/"
chmod +x "$OUTPUT_DIR/ocrmypdf-bin" "$OUTPUT_DIR/bin/"*

# Copy every non-system dylib reachable from the helper binaries, then change
# each reference to a relative path. Dependencies with equal basenames but
# different content are rejected: silently choosing one would be unsafe.
queue=("$OUTPUT_DIR/ocrmypdf-bin" "$OUTPUT_DIR/bin/tesseract" "$OUTPUT_DIR/bin/gs" "$OUTPUT_DIR/bin/qpdf")
while ((${#queue[@]})); do
  current="${queue[0]}"
  queue=("${queue[@]:1}")
  while IFS= read -r dependency; do
    if [[ "$dependency" == @rpath/* ]]; then
      dylib_name="$(basename "$dependency")"
      resolved=''
      old_ifs="$IFS"
      IFS=':'
      for root in $DYLIB_SEARCH_DIRS; do
        [[ -d "$root" ]] || continue
        resolved="$(/usr/bin/find -L "$root" -type f -name "$dylib_name" -print -quit 2>/dev/null || true)"
        [[ -n "$resolved" ]] && break
      done
      IFS="$old_ifs"
      [[ -n "$resolved" ]] || { echo "Cannot resolve $dependency; add its parent tree to DYLIB_SEARCH_DIRS" >&2; exit 1; }
      dependency="$resolved"
    fi
    [[ "$dependency" == /usr/lib/* || "$dependency" == /System/Library/* ]] && continue
    [[ "$dependency" == /* && -f "$dependency" ]] || continue
    name="$(basename "$dependency")"
    destination="$OUTPUT_DIR/lib/$name"
    if [[ -f "$destination" ]]; then
      cmp -s "$destination" "$dependency" || { echo "Dylib basename collision: $name" >&2; exit 1; }
    else
      cp "$dependency" "$destination"
      queue+=("$destination")
    fi
  done < <(/usr/bin/otool -L "$current" 2>/dev/null | /usr/bin/awk 'NR > 1 { print $1 }')
done

rewrite_references() {
  local target="$1" base dependency replacement
  if [[ "$target" == "$OUTPUT_DIR/lib/"* ]]; then
    base='@loader_path'
    /usr/bin/install_name_tool -id "@rpath/$(basename "$target")" "$target" 2>/dev/null || true
  elif [[ "$target" == "$OUTPUT_DIR/bin/"* ]]; then
    base='@loader_path/../lib'
  else
    base='@loader_path/lib'
  fi
  while IFS= read -r dependency; do
    [[ "$dependency" == /usr/lib/* || "$dependency" == /System/Library/* ]] && continue
    replacement="$base/$(basename "$dependency")"
    [[ -f "$OUTPUT_DIR/lib/$(basename "$dependency")" ]] || continue
    /usr/bin/install_name_tool -change "$dependency" "$replacement" "$target"
  done < <(/usr/bin/otool -L "$target" 2>/dev/null | /usr/bin/awk 'NR > 1 { print $1 }')
}
while IFS= read -r binary; do rewrite_references "$binary"; done < <(/usr/bin/find "$OUTPUT_DIR" -type f -perm -u+x)
while IFS= read -r dylib; do rewrite_references "$dylib"; done < <(/usr/bin/find "$OUTPUT_DIR/lib" -type f)
# install_name_tool invalidates upstream signatures. Ad-hoc sign during the
# build so macOS can execute the helpers; package_release.sh later applies the
# Developer ID signature from inner code outward.
while IFS= read -r code; do /usr/bin/codesign --force --sign - "$code"; done < <(/usr/bin/find "$OUTPUT_DIR" \( -path "$OUTPUT_DIR/lib/*" -o -perm -u+x \) -type f)

cat >"$OUTPUT_DIR/ocrmypdf" <<'WRAPPER'
#!/bin/sh
set -eu
BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export PATH="$BASE_DIR/bin:$PATH"
export TESSDATA_PREFIX="$BASE_DIR/tessdata"
export GS_LIB="$BASE_DIR/ghostscript/Init:$BASE_DIR/ghostscript/Font"
exec "$BASE_DIR/ocrmypdf-bin" "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/ocrmypdf"

"$ROOT_DIR/script/audit_runtime.sh" "$OUTPUT_DIR" ocrmypdf
"$OUTPUT_DIR/ocrmypdf" --version
TESSDATA_PREFIX="$OUTPUT_DIR/tessdata" "$OUTPUT_DIR/bin/tesseract" --list-langs | grep -qx 'vie'
echo "OCRmyPDF runtime: $OUTPUT_DIR"
