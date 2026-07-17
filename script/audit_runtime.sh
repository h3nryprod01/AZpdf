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

while IFS= read -r link; do
  target="$(readlink "$link")"
  if [[ "$target" == /* ]]; then
    resolved="$target"
  else
    resolved_dir="$(cd "$(dirname "$link")/$(dirname "$target")" && pwd -P)"
    resolved="$resolved_dir/$(basename "$target")"
  fi
  case "$resolved" in
    "$RUNTIME_DIR"/*) ;;
    *)
      echo "Runtime audit failed: symlink escapes the runtime: $link -> $target" >&2
      exit 1
      ;;
  esac
done < <(find "$RUNTIME_DIR" -type l -print)

while IFS= read -r -d '' candidate; do
  candidate_type="$(file -b "$candidate")"
  # A runtime wrapper may be a shell script (for example a bundled Java app).
  # It must not retain the developer machine's Homebrew paths or an external
  # Python interpreter in its shebang.
  if [[ "$candidate_type" == *text* ]]; then
    if rg -q '/opt/homebrew|/usr/local/Cellar|/usr/local/opt' "$candidate"; then
      echo "Runtime audit failed: Homebrew reference remains in $candidate" >&2
      exit 1
    fi
    shebang="$(head -n 1 "$candidate" 2>/dev/null || true)"
    if [[ "$shebang" == '#!'* ]] && [[ "$shebang" == *python* ]]; then
      echo "Runtime audit failed: Python script entrypoint is not self-contained: $candidate" >&2
      exit 1
    fi
  fi

  if [[ "$candidate_type" == *Mach-O* ]]; then
    library_id="$(otool -D "$candidate" 2>/dev/null | tail -n +2 | head -n 1 || true)"
    dependencies="$(otool -L "$candidate" | tail -n +2 | awk '{print $1}' | { if [[ -n "$library_id" ]]; then grep -Fvx "$library_id" || true; else cat; fi; })"
    if rg -q '/opt/homebrew|/usr/local/Cellar|/usr/local/opt' <<<"$dependencies"; then
      echo "Runtime audit failed: non-relocatable dependency remains in $candidate" >&2
      otool -L "$candidate" >&2
      exit 1
    fi
    if rg -q '^@rpath/' <<<"$dependencies"; then
      rpaths="$(otool -l "$candidate" | awk '/cmd LC_RPATH/{getline; getline; if ($1 == "path") print $2}')"
      if [[ -z "$rpaths" ]] || rg -qv '^@loader_path|^@executable_path' <<<"$rpaths"; then
        echo "Runtime audit failed: @rpath is not confined to the bundle in $candidate" >&2
        otool -L "$candidate" >&2
        exit 1
      fi
    fi
  fi
done < <(find "$RUNTIME_DIR" -type f \( -perm -111 -o -name '*.dylib' \) -print0)

echo "Runtime audit passed: $RUNTIME_DIR"
