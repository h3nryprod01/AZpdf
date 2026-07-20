#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != 'Linux' ]]; then
  echo 'build_flatpak_source.sh chỉ chạy trên Linux.' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID='io.github.h3nryprod01.AZpdf'
MANIFEST="${ROOT}/Packaging/flatpak/${APP_ID}.Source.yml"
BUILD_DIR="${ROOT}/.flatpak-source-build"
REPO_DIR="${ROOT}/.flatpak-source-repo"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1784310724}"

command -v flatpak >/dev/null
command -v flatpak-builder >/dev/null
flatpak info --user org.freedesktop.Sdk//25.08 >/dev/null
flatpak info --user org.freedesktop.Sdk.Extension.swift6//25.08 >/dev/null

"${ROOT}/script/generate_flatpak_pub_sources.py" \
  "${ROOT}/Shell/azpdf_desktop/pubspec.lock" \
  "${ROOT}/Packaging/flatpak/flutter-pub-sources.json" \
  --additional-lockfile "${ROOT}/Packaging/flatpak/flutter-3.44.0-tools-pubspec.lock" \
  --check
"${ROOT}/script/stage_flatpak_source.sh"

rm -rf "${BUILD_DIR}" "${REPO_DIR}"
flatpak-builder \
  --user \
  --force-clean \
  --sandbox \
  --disable-download \
  --bundle-sources \
  --repo="${REPO_DIR}" \
  "${BUILD_DIR}" \
  "${MANIFEST}"

flatpak install --user -y --reinstall "${REPO_DIR}" "${APP_ID}"
flatpak run --user --command=/app/azpdf/azpdf-engine "${APP_ID}" health

permissions="$(flatpak info --user --show-permissions "${APP_ID}")"
printf '%s\n' "${permissions}"
if grep -Eq '(^|;)network(;|$)|filesystems=(host|home)|org\.freedesktop\.Flatpak=talk' <<<"${permissions}"; then
  echo 'AZpdf Flatpak source build có quyền rộng hơn policy cho phép.' >&2
  exit 3
fi

echo "AZpdf Flatpak source build installed: ${APP_ID}"
