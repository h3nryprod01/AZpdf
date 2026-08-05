#!/usr/bin/env bash
# Đóng gói một Linux release bundle (do build_linux_release.sh tạo ra) thành
# AppImage. Gói đúng hai bước: dựng AppDir rồi chạy appimagetool. Chạy trên Linux.
#
# Cách dùng:
#   ./script/build_linux_appimage.sh [BUNDLE_DIR]
#
# BUNDLE_DIR mặc định trỏ tới bundle release Flutter dựng ở Shell/azpdf_desktop.
# Có thể ghi đè bằng biến: APPIMAGETOOL (đường dẫn appimagetool), OUTPUT (file ra).
#
# AppImage này KHÔNG tự chứa hoàn toàn — đo trong container ubuntu:24.04 trắng:
#   libgtk-3-0t64  libegl1  libgl1  libgles2
# là bốn gói hệ thống bắt buộc phải có, cộng một display server. Thiếu chúng thì
# app chết ngay lúc load với "cannot open shared object file", không phải lỗi
# đóng gói: shell Flutter link động GTK3 + GL, đó là cách Flutter Linux hoạt động.
# Mọi desktop Linux dùng GTK (GNOME, XFCE, Cinnamon, MATE) đã có sẵn cả bốn, nên
# với người dùng thật thì tải một file về là chạy; chỉ hệ thống tối giản hoặc
# container trắng mới cần cài thêm. PHẢI ghi điều này vào tài liệu tải về —
# đừng quảng cáo AppImage là "self-contained".
#
# Ngược lại, phần engine THÌ tự chứa thật: đã verify `azpdf-engine health` trả
# {"ok":true} với mutool 1.28.0 trong đúng container trắng đó, không cài gì thêm.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "build_linux_appimage.sh chỉ chạy trên Linux." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="io.github.h3nryprod01.AZpdf"
BINARY="azpdf_desktop"
ICON_SRC="$ROOT/Assets/AZpdf-icon.png"
BUNDLE_DIR="${1:-$ROOT/Shell/azpdf_desktop/build/linux/x64/release/bundle}"
APPIMAGETOOL="${APPIMAGETOOL:-$HOME/appimagetool}"
OUTPUT="${OUTPUT:-$ROOT/AZpdf-x86_64.AppImage}"

if [[ ! -x "$BUNDLE_DIR/$BINARY" ]]; then
  echo "BUNDLE_DIR phải chứa executable $BINARY: $BUNDLE_DIR" >&2
  echo "Chạy script/build_linux_release.sh trước." >&2
  exit 1
fi
for need in azpdf-engine mutool; do
  if [[ ! -x "$BUNDLE_DIR/$need" ]]; then
    echo "Thiếu $need trong bundle: $BUNDLE_DIR" >&2
    exit 1
  fi
done
if [[ ! -f "$ICON_SRC" ]]; then
  echo "Thiếu icon nguồn: $ICON_SRC" >&2
  exit 1
fi
if ! command -v convert >/dev/null 2>&1; then
  echo "Cần ImageMagick (convert) để tạo icon. Cài: sudo apt-get install -y imagemagick" >&2
  exit 1
fi

APPDIR="$ROOT/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
  "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps"

cp -a "$BUNDLE_DIR/." "$APPDIR/usr/bin/"

convert "$ICON_SRC" -resize 256x256 \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/$APP_ID.png"

cat > "$APPDIR/usr/share/applications/$APP_ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=AZpdf
Comment=Local-first PDF reader and editor
Exec=$BINARY %f
Icon=$APP_ID
Categories=Office;Viewer;
MimeType=application/pdf;
Terminal=false
DESKTOP
cp "$APPDIR/usr/share/applications/$APP_ID.desktop" "$APPDIR/"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
# AppImage entry point. HERE is the mounted AppDir; the Flutter bundle keeps its
# libraries next to the binary, so the loader needs that directory on the path.
HERE=$(dirname $(readlink -f "$0"))
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:$LD_LIBRARY_PATH"

# Đường dẫn tương đối phải thành tuyệt đối NGAY TẠI ĐÂY, chỗ duy nhất $PWD còn là thư mục
# người dùng thật sự gọi lệnh. Đo được 2026-08-05: chạy `./AZpdf.AppImage ./tài-liệu.pdf`
# thì /proc/<pid>/cwd của app trỏ về $HOME, không phải thư mục gọi — runtime của AppImage đổi
# thư mục làm việc trước khi app khởi động (AppRun này không hề `cd`). Hệ quả: file mở ra rỗng,
# không báo lỗi gì. Dùng `set --` để dựng lại danh sách tham số cho an toàn với tên có dấu cách.
n=$#
i=0
while [ "$i" -lt "$n" ]; do
  a="$1"; shift
  case "$a" in
    /*) set -- "$@" "$a" ;;
    *) if [ -e "$PWD/$a" ]; then set -- "$@" "$PWD/$a"; else set -- "$@" "$a"; fi ;;
  esac
  i=$((i + 1))
done

exec "$HERE/usr/bin/azpdf_desktop" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

if [[ ! -x "$APPIMAGETOOL" ]]; then
  echo "Tải appimagetool..."
  curl -fsSL -o "$APPIMAGETOOL" \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$APPIMAGETOOL"
fi

ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"

echo "AppImage: $OUTPUT"
