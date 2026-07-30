#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# grep, not ripgrep, and the exit status read explicitly — see the long note in
# audit_local_first.sh. Same fail-open bug: rg is absent on the macOS runner, so
# `if rg ...` treated exit 127 as "no match" and this gate reported that Core
# stayed Foundation-only without ever having looked.
set +e
hits="$(grep -REn --include='*.swift' '^import (AppKit|PDFKit|SwiftUI|UIKit|WinSDK)$' Core)"
status=$?
set -e

case "$status" in
  0)
    printf '%s\n' "$hits" >&2
    echo "Portable-core audit failed: platform UI/PDF framework imported by Core." >&2
    exit 1
    ;;
  1) ;;
  *)
    echo "Portable-core audit could not run: grep exited $status; scan incomplete." >&2
    exit 1
    ;;
esac

echo "Portable-core audit passed: Core remains Foundation-only."
