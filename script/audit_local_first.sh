#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Explicitly user-initiated Link views are allowed. This gate rejects code that
# could open sockets or issue HTTP requests without the user's PDF-share action.
FORBIDDEN='URLSession|URLRequest|NWConnection|NWListener|WebSocketTask|URLSessionWebSocketTask'

# grep, not ripgrep: rg is not installed on the GitHub macOS runner. That matters
# more than a missing tool normally would, because `if rg ...; then fail; fi`
# reads a missing binary (exit 127) as "nothing matched" and falls straight
# through to the success line — `set -e` is suspended inside an `if` condition.
# This gate therefore printed "passed" in CI while scanning nothing at all: a
# URLSession.shared planted in Core/ went undetected. Since README.md advertises
# that CI blocks networking APIs, a silent pass here makes the project's central
# privacy claim untrue in the one place users are asked to trust it. The exit
# status is now read explicitly — 0 = match, 1 = genuinely clean, anything else
# = the scan itself broke, which must fail closed. CI plants a probe violation
# on every run to prove the gate still bites.
set +e
hits="$(grep -REn --include='*.swift' "$FORBIDDEN" App Core Models Services Stores Support Views)"
status=$?
set -e

case "$status" in
  0)
    printf '%s\n' "$hits" >&2
    echo "Local-first audit failed: networking API detected in AZpdf source." >&2
    exit 1
    ;;
  1) ;;
  *)
    echo "Local-first audit could not run: grep exited $status; scan incomplete." >&2
    exit 1
    ;;
esac

echo "Local-first audit passed: no network client API found."
