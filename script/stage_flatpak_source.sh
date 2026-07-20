#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${AZPDF_FLATPAK_SOURCE_STAGE:-${ROOT}/Packaging/flatpak/dev/source}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "${ROOT}" log -1 --format=%ct)}"

command -v rsync >/dev/null
[[ "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]] || {
  echo 'SOURCE_DATE_EPOCH phải là số nguyên Unix timestamp.' >&2
  exit 2
}

rm -rf "${STAGE}"
mkdir -p "${STAGE}"
rsync -a --delete \
  --exclude '/.git/' \
  --exclude '/.build/' \
  --exclude '/.build-*/' \
  --exclude '/.dart_tool/' \
  --exclude '/.flatpak-*/' \
  --exclude '/.codegraph/' \
  --exclude '/.codex/' \
  --exclude '/.cursor/' \
  --exclude '/dist/' \
  --exclude '/outputs/' \
  --exclude '/Packaging/flatpak/dev/' \
  --exclude '/qa-report/' \
  --exclude '/Shell/azpdf_desktop/build/' \
  --exclude '/Tests/Fixtures/generated/' \
  --exclude '/work/' \
  --exclude '*.log' \
  "${ROOT}/" "${STAGE}/"

if date -d "@${SOURCE_DATE_EPOCH}" '+%Y%m%d%H%M.%S' >/dev/null 2>&1; then
  normalized_time="$(date -u -d "@${SOURCE_DATE_EPOCH}" '+%Y%m%d%H%M.%S')"
else
  normalized_time="$(date -u -r "${SOURCE_DATE_EPOCH}" '+%Y%m%d%H%M.%S')"
fi
printf '%s\n' "${SOURCE_DATE_EPOCH}" >"${STAGE}/.source-date-epoch"
find "${STAGE}" -exec touch -h -t "${normalized_time}" {} +

for required in \
  Package.swift \
  Package.resolved \
  Shell/azpdf_desktop/pubspec.lock \
  Shell/azpdf_desktop/linux/CMakeLists.txt \
  Tools/AZpdfEngineCLI/main.swift; do
  [[ -f "${STAGE}/${required}" ]] || {
    echo "Source stage thiếu ${required}" >&2
    exit 3
  }
done

echo "AZpdf Flatpak source stage: ${STAGE}"
echo "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
