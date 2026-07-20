#!/usr/bin/env bash
set -euo pipefail

APP_ID='io.github.h3nryprod01.AZpdf'

if [[ "${1:-}" == '--inside-session' ]]; then
  output_dir="$2"
  app_log="${output_dir}/azpdf-flatpak-app.log"
  flatpak_args=(run --user --env=GDK_BACKEND=x11)
  command_args=()
  if [[ -n "${AZPDF_FLATPAK_TEST_PDF:-}" ]]; then
    # Flatpak exposes the portal at /run/user/$UID/doc in a real login session.
    # The isolated session uses a temporary host runtime pathname,
    # so mirror only that pathname to Flatpak's portal mount inside private
    # /tmp. No host or home filesystem permission is added.
    flatpak_args+=(--command=sh)
    command_args=(
      -c
      'mkdir -p "$1"; ln -s /run/user/$(id -u)/doc "$1/doc"; exec /app/azpdf/azpdf_desktop'
      sh
      "${XDG_RUNTIME_DIR}"
    )
  fi
  flatpak "${flatpak_args[@]}" "${APP_ID}" "${command_args[@]}" >"${app_log}" 2>&1 &
  app_pid=$!
  cleanup_inside() {
    kill "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" 2>/dev/null || true
  }
  trap cleanup_inside EXIT

  main_window=''
  for _ in $(seq 1 80); do
    main_window="$(xdotool search --onlyvisible --name '^AZpdf$' 2>/dev/null | head -1 || true)"
    if [[ -n "${main_window}" ]]; then break; fi
    if ! kill -0 "${app_pid}" 2>/dev/null; then
      cat "${app_log}" >&2
      exit 20
    fi
    sleep 0.25
  done
  if [[ -z "${main_window}" ]]; then
    xwininfo -root -tree >&2
    cat "${app_log}" >&2
    exit 21
  fi

  scrot --overwrite "${output_dir}/azpdf-flatpak-home.png"
  xdotool windowfocus --sync "${main_window}"
  xdotool key --window "${main_window}" ctrl+o

  chooser_window=''
  for _ in $(seq 1 80); do
    chooser_window="$(xdotool search --onlyvisible --name 'Open|Mở' 2>/dev/null | grep -v "^${main_window}$" | head -1 || true)"
    if [[ -n "${chooser_window}" ]]; then break; fi
    sleep 0.25
  done
  if [[ -z "${chooser_window}" ]]; then
    xwininfo -root -tree >&2
    cat "${app_log}" >&2
    exit 22
  fi

  scrot --overwrite "${output_dir}/azpdf-flatpak-command-o.png"
  if [[ -n "${AZPDF_FLATPAK_TEST_PDF:-}" ]]; then
    test -f "${AZPDF_FLATPAK_TEST_PDF}"
    xdotool windowfocus --sync "${chooser_window}"
    xdotool key ctrl+l
    sleep 0.25
    xdotool type --delay 1 -- "${AZPDF_FLATPAK_TEST_PDF}"
    sleep 0.25
    xdotool key Return
    sleep 0.75
    # GTK's location entry may resolve the path first and require a second
    # confirmation to activate the selected file.
    if xdotool getwindowname "${chooser_window}" >/dev/null 2>&1; then
      xdotool key Return
    fi
    for _ in $(seq 1 80); do
      if ! xdotool getwindowname "${chooser_window}" >/dev/null 2>&1; then break; fi
      sleep 0.25
    done
    if xdotool getwindowname "${chooser_window}" >/dev/null 2>&1; then
      xwininfo -root -tree >&2
      exit 23
    fi
    sleep 2
    if ! kill -0 "${app_pid}" 2>/dev/null; then
      cat "${app_log}" >&2
      exit 24
    fi
    scrot --overwrite "${output_dir}/azpdf-flatpak-pdf-open.png"
    tesseract \
      "${output_dir}/azpdf-flatpak-pdf-open.png" \
      "${output_dir}/azpdf-flatpak-pdf-open" \
      -l eng --psm 6 >/dev/null 2>&1
    ocr_text="$(cat "${output_dir}/azpdf-flatpak-pdf-open.txt")"
    if [[ "${ocr_text}" == *'PathNotFoundException'* ]]; then
      echo 'Portal đóng nhưng AZpdf không đọc được tài liệu.' >&2
      exit 25
    fi
    if [[ -n "${AZPDF_FLATPAK_EXPECT_TEXT:-}" && "${ocr_text}" != *"${AZPDF_FLATPAK_EXPECT_TEXT}"* ]]; then
      echo 'Không xác nhận được nội dung PDF trong cửa sổ AZpdf.' >&2
      printf '%s\n' "${ocr_text}" >&2
      exit 26
    fi
    printf 'FLATPAK_PORTAL_OPEN_PASS file=%s\n' "${AZPDF_FLATPAK_TEST_PDF}"
  else
    xdotool key --window "${chooser_window}" Escape || true
  fi
  printf 'FLATPAK_GUI_PASS window=%s chooser=%s\n' "${main_window}" "${chooser_window}"
  exit 0
fi

if [[ "$(uname -s)" != 'Linux' ]]; then
  echo 'test_flatpak_gui.sh chỉ chạy trên Linux.' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${ROOT}/qa-report/linux-flatpak}"
DISPLAY_NUMBER="${AZPDF_XVFB_DISPLAY:-:98}"
RUNTIME_DIR="$(mktemp -d /tmp/azpdf-flatpak-xdg-XXXXXX)"
CONFIG_DIR="${RUNTIME_DIR}/config"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${CONFIG_DIR}/xdg-desktop-portal"
chmod 700 "${RUNTIME_DIR}"
printf '[preferred]\ndefault=gtk\n' > "${CONFIG_DIR}/xdg-desktop-portal/portals.conf"

Xvfb "${DISPLAY_NUMBER}" -screen 0 1920x1080x24 -nolisten tcp >"${OUTPUT_DIR}/xvfb.log" 2>&1 &
xvfb_pid=$!
cleanup_outer() {
  kill "${xvfb_pid}" 2>/dev/null || true
  wait "${xvfb_pid}" 2>/dev/null || true
  rm -rf "${RUNTIME_DIR}"
}
trap cleanup_outer EXIT

export DISPLAY="${DISPLAY_NUMBER}"
for _ in $(seq 1 40); do
  if xdpyinfo >/dev/null 2>&1; then break; fi
  sleep 0.25
done
xdpyinfo >/dev/null

XDG_RUNTIME_DIR="${RUNTIME_DIR}" \
XDG_CONFIG_HOME="${CONFIG_DIR}" \
XDG_CURRENT_DESKTOP='GNOME' \
XDG_SESSION_DESKTOP='GNOME' \
DBUS_SESSION_BUS_ADDRESS='' \
AZPDF_FLATPAK_TEST_PDF="${AZPDF_FLATPAK_TEST_PDF:-}" \
AZPDF_FLATPAK_EXPECT_TEXT="${AZPDF_FLATPAK_EXPECT_TEXT:-}" \
dbus-run-session -- "${BASH_SOURCE[0]}" --inside-session "${OUTPUT_DIR}"
