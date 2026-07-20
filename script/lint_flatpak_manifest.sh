#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${1:-${ROOT}/Packaging/flatpak/io.github.h3nryprod01.AZpdf.Source.yml}"
MODE="${2:-development}"

command -v flatpak-builder >/dev/null
command -v jq >/dev/null
[[ -f "${MANIFEST}" ]] || { echo "Không tìm thấy manifest: ${MANIFEST}" >&2; exit 2; }
[[ "${MODE}" == 'development' || "${MODE}" == 'public' ]] || {
  echo 'Mode phải là development hoặc public.' >&2
  exit 2
}

canonical="$(mktemp)"
trap 'rm -f "${canonical}"' EXIT
flatpak-builder --show-manifest "${MANIFEST}" >"${canonical}"

jq -e '
  .id == "io.github.h3nryprod01.AZpdf" and
  .runtime == "org.freedesktop.Platform" and
  .sdk == "org.freedesktop.Sdk" and
  (."runtime-version" == "25.08") and
  (."sdk-extensions" | index("org.freedesktop.Sdk.Extension.swift6") != null) and
  all(."finish-args"[];
    (test("^--share=network$") or
     test("^--filesystem=(host|home)(:|$)") or
     test("^--talk-name=org\\.freedesktop\\.Flatpak$")) | not
  )
' "${canonical}" >/dev/null

jq -e '
  def remote_sources:
    [.. | objects | select(has("type") and has("url"))];
  all(remote_sources[];
    if (.type == "archive" or .type == "file") then
      (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    elif .type == "git" then
      (.commit | type == "string" and test("^[0-9a-f]{40}$"))
    else
      false
    end
  )
' "${canonical}" >/dev/null

if jq -e '[.modules[]."build-commands"[]? | select(test("(^|[ ;])(curl|wget|git clone)([ ;]|$)"))] | length > 0' "${canonical}" >/dev/null; then
  echo 'Build command không được tải source trực tiếp.' >&2
  exit 3
fi
if jq -e '[.modules[]."build-commands"[]? | select(test("pub.*get") and (test("--offline") | not))] | length > 0' "${canonical}" >/dev/null; then
  echo 'Mọi lệnh pub get phải chạy --offline.' >&2
  exit 3
fi

if [[ "${MODE}" == 'public' ]]; then
  if jq -e '[.. | objects | select(.type? == "dir")] | length > 0' "${canonical}" >/dev/null; then
    echo 'Public manifest không được dùng source type dir; pin git commit hoặc archive SHA-256.' >&2
    exit 4
  fi
fi

echo "Flatpak manifest lint pass (${MODE}): ${MANIFEST}"
