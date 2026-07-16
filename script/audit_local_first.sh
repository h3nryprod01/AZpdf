#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Explicitly user-initiated Link views are allowed. This gate rejects code that
# could open sockets or issue HTTP requests without the user's PDF-share action.
FORBIDDEN='URLSession|URLRequest|NWConnection|NWListener|WebSocketTask|URLSessionWebSocketTask'

if rg -n --glob '*.swift' "$FORBIDDEN" App Core Models Services Stores Support Views; then
  echo "Local-first audit failed: networking API detected in AZpdf source." >&2
  exit 1
fi

echo "Local-first audit passed: no network client API found."
