#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if rg -n '^import (AppKit|PDFKit|SwiftUI|UIKit|WinSDK)$' Core; then
  echo "Portable-core audit failed: platform UI/PDF framework imported by Core." >&2
  exit 1
fi

echo "Portable-core audit passed: Core remains Foundation-only."
