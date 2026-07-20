#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_DIR="${ROOT_DIR}/Packaging/flatpak/probe"
BUILD_DIR="${ROOT_DIR}/.flatpak-probe-build"
REPO_DIR="${ROOT_DIR}/.flatpak-probe-repo"
APP_ID='io.azpdf.AZpdf.SandboxProbe'

command -v flatpak >/dev/null
command -v flatpak-builder >/dev/null

rm -rf "${BUILD_DIR}" "${REPO_DIR}"
flatpak-builder \
  --user \
  --force-clean \
  --repo="${REPO_DIR}" \
  "${BUILD_DIR}" \
  "${PROBE_DIR}/${APP_ID}.yml"
flatpak install --user -y --reinstall "${REPO_DIR}" "${APP_ID}"

host_marker="${HOME}/azpdf-flatpak-host-secret.txt"
printf 'host-only-secret\n' > "${host_marker}"
chmod 600 "${host_marker}"
cleanup() {
  rm -f "${host_marker}"
}
trap cleanup EXIT

output="$(flatpak run --user "${APP_ID}")"
printf '%s\n' "${output}"
grep -q '^FLATPAK_PROBE_PASS$' <<< "${output}"

permissions="$(flatpak info --user --show-permissions "${APP_ID}")"
printf '%s\n' "${permissions}"
if grep -Eq '(^|;)network(;|$)|filesystems=(host|home)|org\.freedesktop\.Flatpak=talk' <<< "${permissions}"; then
  echo 'Flatpak probe has broader permissions than expected.' >&2
  exit 30
fi
