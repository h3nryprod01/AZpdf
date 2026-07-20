#!/usr/bin/env bash
set -euo pipefail

APP_ID='io.github.h3nryprod01.AZpdf'

if [[ "$(uname -s)" != 'Linux' ]]; then
  echo 'test_flatpak_desktop_session.sh chỉ chạy trên Linux.' >&2
  exit 1
fi

if [[ "${AZPDF_ALLOW_ACTIVE_DESKTOP_TEST:-}" != 'YES' ]]; then
  echo 'Đặt AZPDF_ALLOW_ACTIVE_DESKTOP_TEST=YES sau khi đã đóng nội dung riêng tư trên desktop.' >&2
  exit 2
fi

if [[ -z "${DISPLAY:-}" || -z "${XAUTHORITY:-}" ]]; then
  echo 'Cần DISPLAY và XAUTHORITY của phiên desktop X11 đang hoạt động.' >&2
  exit 3
fi

if [[ -z "${AZPDF_FLATPAK_TEST_PDF:-}" ]]; then
  echo 'Cần AZPDF_FLATPAK_TEST_PDF trỏ tới PDF fixture.' >&2
  exit 4
fi
test -f "${AZPDF_FLATPAK_TEST_PDF}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${ROOT}/qa-report/linux-flatpak}"
mkdir -p "${OUTPUT_DIR}"
app_log="${OUTPUT_DIR}/azpdf-flatpak-desktop-app.log"

flatpak run --user --env=GDK_BACKEND=x11 "${APP_ID}" >"${app_log}" 2>&1 &
app_pid=$!
cleanup() {
  kill "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" 2>/dev/null || true
}
trap cleanup EXIT

main_window=''
for _ in $(seq 1 120); do
  main_window="$(xdotool search --onlyvisible --class 'io.github.h3nryprod01.AZpdf' 2>/dev/null | head -1 || true)"
  if [[ -n "${main_window}" ]]; then break; fi
  if ! kill -0 "${app_pid}" 2>/dev/null; then
    cat "${app_log}" >&2
    exit 20
  fi
  sleep 0.25
done
if [[ -z "${main_window}" ]]; then
  cat "${app_log}" >&2
  exit 21
fi

xdotool windowactivate --sync "${main_window}"
xdotool key ctrl+o

chooser_window=''
for _ in $(seq 1 120); do
  chooser_window="$(xdotool search --onlyvisible --name 'Open|Mở|Select.*File' 2>/dev/null | grep -v "^${main_window}$" | tail -1 || true)"
  if [[ -n "${chooser_window}" ]]; then break; fi
  sleep 0.25
done
if [[ -z "${chooser_window}" ]]; then
  xwininfo -root -tree >&2
  cat "${app_log}" >&2
  exit 22
fi

xdotool windowactivate --sync "${chooser_window}"
xdotool key ctrl+l
sleep 0.25
xdotool type --delay 1 -- "${AZPDF_FLATPAK_TEST_PDF}"
sleep 0.25
xdotool key Return
sleep 0.75
if xdotool search --onlyvisible --name 'Open|Mở|Select.*File' 2>/dev/null | grep -q "^${chooser_window}$"; then
  xdotool key Return
fi

for _ in $(seq 1 120); do
  if ! xdotool search --onlyvisible --name 'Open|Mở|Select.*File' 2>/dev/null | grep -q "^${chooser_window}$"; then
    break
  fi
  sleep 0.25
done
if xdotool search --onlyvisible --name 'Open|Mở|Select.*File' 2>/dev/null | grep -q "^${chooser_window}$"; then
  exit 23
fi

sleep 4
if ! kill -0 "${app_pid}" 2>/dev/null; then
  cat "${app_log}" >&2
  exit 24
fi
xdotool windowactivate --sync "${main_window}"
scrot --overwrite --focused "${OUTPUT_DIR}/azpdf-flatpak-kde-pdf-open.png"
tesseract "${OUTPUT_DIR}/azpdf-flatpak-kde-pdf-open.png" "${OUTPUT_DIR}/azpdf-flatpak-kde-pdf-open" -l eng >/dev/null 2>&1

ocr_text="$(cat "${OUTPUT_DIR}/azpdf-flatpak-kde-pdf-open.txt")"
if [[ "${ocr_text}" == *'PathNotFoundException'* ]]; then
  echo 'Portal đóng nhưng AZpdf không đọc được tài liệu.' >&2
  exit 25
fi
if [[ "${ocr_text}" != *'AZpdf engine fixture'* && "${ocr_text}" != *'Portable open'* ]]; then
  echo 'Không xác nhận được nội dung PDF trong cửa sổ AZpdf.' >&2
  printf '%s\n' "${ocr_text}" >&2
  exit 26
fi

printf 'FLATPAK_KDE_PORTAL_OPEN_PASS file=%s window=%s\n' "${AZPDF_FLATPAK_TEST_PDF}" "${main_window}"
