#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo 'build_flatpak_dev.sh chỉ chạy trên Linux.' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID='io.github.h3nryprod01.AZpdf'
PACKAGING_DIR="${ROOT}/Packaging/flatpak"
BUNDLE="${AZPDF_LINUX_BUNDLE:-${ROOT}/Shell/azpdf_desktop/build/linux/x64/release/bundle}"
STAGE="${PACKAGING_DIR}/dev/bundle"
BUILD_DIR="${ROOT}/.flatpak-build"
REPO_DIR="${ROOT}/.flatpak-repo"

command -v flatpak >/dev/null
command -v flatpak-builder >/dev/null
if [[ ! -x "${BUNDLE}/azpdf_desktop" || ! -x "${BUNDLE}/azpdf-engine" || ! -x "${BUNDLE}/mutool" ]]; then
  echo "Bundle Linux Release chưa đầy đủ: ${BUNDLE}" >&2
  exit 2
fi

rm -rf "${STAGE}" "${BUILD_DIR}" "${REPO_DIR}"
mkdir -p "${STAGE}"
cp -a "${BUNDLE}/." "${STAGE}/"

flatpak-builder \
  --user \
  --force-clean \
  --repo="${REPO_DIR}" \
  "${BUILD_DIR}" \
  "${PACKAGING_DIR}/${APP_ID}.yml"
flatpak install --user -y --reinstall "${REPO_DIR}" "${APP_ID}"

flatpak run --user --command=/app/azpdf/azpdf-engine "${APP_ID}" health
flatpak run --user --command=/app/azpdf/azpdf-engine "${APP_ID}" ocr-health
flatpak run --user --command=/app/azpdf/azpdf-engine "${APP_ID}" signature-health

permissions="$(flatpak info --user --show-permissions "${APP_ID}")"
printf '%s\n' "${permissions}"
if grep -Eq '(^|;)network(;|$)|filesystems=(host|home)|org\.freedesktop\.Flatpak=talk' <<< "${permissions}"; then
  echo 'AZpdf Flatpak có quyền rộng hơn policy cho phép.' >&2
  exit 3
fi

echo "AZpdf Flatpak development build installed: ${APP_ID}"
