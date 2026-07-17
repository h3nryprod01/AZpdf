#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <runtime-directory> <relative-executable-path>" >&2
  exit 2
fi

RUNTIME_DIR="$1"
EXECUTABLE="$RUNTIME_DIR/$2"

[[ -d "$RUNTIME_DIR" ]] || { echo "Runtime audit failed: directory does not exist: $RUNTIME_DIR" >&2; exit 1; }
[[ -x "$EXECUTABLE" ]] || { echo "Runtime audit failed: expected executable is missing: $EXECUTABLE" >&2; exit 1; }
[[ ! -L "$EXECUTABLE" ]] || { echo "Runtime audit failed: executable must not be a symlink: $EXECUTABLE" >&2; exit 1; }

if find "$RUNTIME_DIR" -type l -print -quit | rg -q .; then
  echo "Runtime audit failed: release runtimes must not contain symlinks." >&2
  exit 1
fi

while IFS= read -r -d '' candidate; do
  if file "$candidate" | rg -q 'Mach-O'; then
    if otool -L "$candidate" | rg -q '/opt/homebrew|/usr/local/Cellar|/usr/local/opt'; then
      echo "Runtime audit failed: Homebrew dependency remains in $candidate" >&2
      otool -L "$candidate" >&2
      exit 1
    fi
  fi
done < <(find "$RUNTIME_DIR" -type f \( -perm -111 -o -name '*.dylib' \) -print0)

echo "Runtime audit passed: $RUNTIME_DIR"
