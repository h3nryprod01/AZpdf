#!/usr/bin/env bash
# AZpdf — QA smoke test cho Linux.
#
# Chạy trên máy Ubuntu:   bash script/qa_linux_smoke.sh
# Tuỳ chọn:               REPO=/duong/dan/toi/repo bash script/qa_linux_smoke.sh
#
# Script chỉ ĐỌC repo và ghi file tạm vào $OUT. Không sửa source, không commit.
# Kết thúc sẽ in bảng tổng kết — copy nguyên phần đó gửi lại.

set -uo pipefail

REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT="${OUT:-${TMPDIR:-/tmp}/azpdf-qa-linux}"
FX="$OUT/fixtures"
mkdir -p "$FX"

PASS=0; FAIL=0; SKIP=0
declare -a RESULTS

ok()   { RESULTS+=("PASS  $1"); PASS=$((PASS+1)); }
bad()  { RESULTS+=("FAIL  $1${2:+  -> $2}"); FAIL=$((FAIL+1)); }
skip() { RESULTS+=("SKIP  $1${2:+  ($2)}"); SKIP=$((SKIP+1)); }

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# Chạy 1 lệnh engine, coi là PASS nếu exit 0 VÀ JSON có "ok":true
engine() {
  local label="$1"; shift
  local output status
  output="$("$ENGINE" "$@" 2>&1)"; status=$?
  if [[ $status -eq 0 && "$output" == *'"ok":true'* ]]; then
    ok "$label"
  else
    bad "$label" "exit=$status ${output:0:160}"
  fi
}

section "1. Prerequisites"
for tool in swift mutool; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "có $tool ($("$tool" --version 2>&1 | head -1 | cut -c1-60))"
  else
    bad "thiếu $tool" "cài rồi chạy lại"
  fi
done

# Engine chạy azpdf_annotations.js qua JS engine của mutool, mà file đó dùng
# `import ... from "mupdf"` (ES module). mutool cũ không parse được và fail bằng
# một SyntaxError khó hiểu, nên kiểm phiên bản ở đây cho rõ ràng.
MUTOOL_OK_FOR_JS=1
if command -v mutool >/dev/null 2>&1; then
  MV=$(mutool -v 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if [[ -n "$MV" ]] && awk "BEGIN{exit !($MV < 1.24)}"; then
    MUTOOL_OK_FOR_JS=0
    skip "mutool $MV quá cũ cho annotations" "cần >= 1.24 (ES module); bundle release mang sẵn 1.28"
  fi
fi
for tool in flutter flatpak ocrmypdf; do
  command -v "$tool" >/dev/null 2>&1 && ok "có $tool (tuỳ chọn)" || skip "$tool" "tuỳ chọn, bỏ qua phần liên quan"
done

command -v swift >/dev/null 2>&1 || { printf '\nKhông có swift — dừng.\n'; exit 2; }

section "2. Build engine CLI"
if swift build --package-path "$REPO" --product azpdf-engine 2>&1 | tail -3; then
  ENGINE="$(swift build --package-path "$REPO" --show-bin-path 2>/dev/null)/azpdf-engine"
  [[ -x "$ENGINE" ]] && ok "build azpdf-engine" || bad "build azpdf-engine" "không thấy binary tại $ENGINE"
else
  bad "build azpdf-engine" "swift build lỗi"
fi
[[ -x "${ENGINE:-}" ]] || { printf '\nKhông build được engine — dừng.\n'; exit 2; }

section "3. Tạo PDF mẫu"
if command -v mutool >/dev/null 2>&1 && [[ -d "$REPO/Tests/Fixtures/source" ]]; then
  OUT_DIR="$FX" bash "$REPO/script/generate_pdf_fixtures.sh" "$FX" >/dev/null 2>&1
  mutool merge -o "$FX/multipage.pdf" "$FX/basic.pdf" "$FX/two-column.pdf" "$FX/rotated.pdf" >/dev/null 2>&1
  count=$(ls "$FX"/*.pdf 2>/dev/null | wc -l | tr -d ' ')
  [[ $count -ge 3 ]] && ok "tạo $count PDF mẫu" || bad "tạo PDF mẫu" "chỉ có $count file"
else
  bad "tạo PDF mẫu" "thiếu mutool hoặc Tests/Fixtures/source"
fi
DOC="$FX/multipage.pdf"; [[ -f "$DOC" ]] || DOC="$FX/basic.pdf"

section "4. Engine — luồng đọc"
engine "health"                 health
engine "info"                   info        --document "$DOC"
engine "page (trang 0)"         page        --document "$DOC" --page 0
engine "text (trang 0)"         text        --document "$DOC" --page 0
engine "search"                 search      --document "$DOC" --query "the"
if [[ $MUTOOL_OK_FOR_JS -eq 1 ]]; then
  engine "annotations"          annotations --document "$DOC" --page 0
fi
engine "render -> PNG"          render      --document "$DOC" --page 0 --scale 1 --output "$OUT/render.png"
[[ -s "$OUT/render.png" ]] && ok "render tạo file không rỗng" || bad "render tạo file" "file rỗng/không có"

section "5. Engine — DocumentIR (đường dùng cho shell Linux)"
engine "ir-baseline"    ir-baseline    --document "$DOC" --output "$OUT/ir.json"
engine "ir-validate"    ir-validate    --input  "$OUT/ir.json"
engine "ir-export-text" ir-export-text --input  "$OUT/ir.json" --output "$OUT/ir.txt"
[[ -s "$OUT/ir.txt" ]] && ok "ir-export-text có nội dung" || bad "ir-export-text" "file rỗng"

section "6. Engine — ghi & runtime tuỳ chọn"
engine "save-as" save-as --document "$DOC" --output "$OUT/copy.pdf"
if command -v ocrmypdf >/dev/null 2>&1; then engine "ocr-health" ocr-health; else skip "ocr-health" "thiếu ocrmypdf"; fi
"$ENGINE" signature-health >/dev/null 2>&1 && ok "signature-health" || skip "signature-health" "thiếu pyhanko runtime"

section "7. Xử lý lỗi (phải fail ĐÚNG cách)"
out="$("$ENGINE" 2>&1)"; [[ "$out" == *'"ok":false'* ]] && ok "không tham số -> envelope lỗi" || bad "không tham số" "${out:0:120}"
out="$("$ENGINE" lenh-khong-ton-tai --document "$DOC" 2>&1)"
[[ "$out" == *'"ok":false'* ]] && ok "lệnh sai -> envelope lỗi" || bad "lệnh sai" "${out:0:120}"
out="$("$ENGINE" info --document /khong/ton/tai.pdf 2>&1)"
[[ "$out" == *'"ok":false'* ]] && ok "file không tồn tại -> envelope lỗi" || bad "file không tồn tại" "${out:0:120}"

section "8. Flatpak / shell (nếu có)"
for s in test_flatpak_sandbox.sh test_flatpak_desktop_session.sh; do
  if [[ -x "$REPO/script/$s" ]] && command -v flatpak >/dev/null 2>&1; then
    if bash "$REPO/script/$s" >"$OUT/$s.log" 2>&1; then
      ok "$s"
    elif grep -q "AZPDF_ALLOW_ACTIVE_DESKTOP_TEST" "$OUT/$s.log" 2>/dev/null; then
      # Script tự chặn để không đụng vào desktop đang có nội dung riêng tư.
      # Đó là guard chạy đúng, không phải lỗi.
      skip "$s" "cần AZPDF_ALLOW_ACTIVE_DESKTOP_TEST=YES, script tự chặn để bảo vệ desktop"
    else
      bad "$s" "xem $OUT/$s.log"
    fi
  else
    skip "$s" "thiếu flatpak hoặc script"
  fi
done

printf '\n\033[1m===== TỔNG KẾT (copy phần này gửi lại) =====\033[0m\n'
printf 'AZpdf QA Linux — %s — %s\n' "$(date '+%F %T')" "$(uname -srm)"
printf 'repo=%s\n\n' "$REPO"
for r in "${RESULTS[@]}"; do printf '%s\n' "$r"; done
printf '\nPASS=%d  FAIL=%d  SKIP=%d\n' "$PASS" "$FAIL" "$SKIP"
printf 'Artifacts: %s\n' "$OUT"

cat <<'CHECKLIST'

===== CHECKLIST GUI THỦ CÔNG (cần mắt người, ~10 phút) =====
Mở shell Linux (Flutter) rồi trả lời Có/Không cho từng mục:

 1. Mở PDF bằng nút trong app     -> có mở được không?
 2. Double-click PDF ở file manager -> có mở bằng AZpdf không?   [macOS FAIL mục này]
 3. Kéo-thả PDF vào cửa sổ        -> có mở không?
 4. Ô TÌM KIẾM có nhìn thấy không? Ctrl+F có mở tìm kiếm không?  [macOS FAIL mục này]
 5. Nút ZOOM +/- và "vừa trang" có nhìn thấy không?              [macOS FAIL mục này]
 6. Điều hướng trang (nút + phím tắt) có đúng số trang không?
 7. Mục lục + thumbnail có hiện và bấm chuyển trang được không?
 8. Mở encrypted.pdf (mật khẩu: secret) -> có hỏi mật khẩu không? Sai mật khẩu có báo lỗi rõ không?
 9. Bôi đen text -> copy được không?
10. Toolbar: có bao nhiêu nút không nhãn? Có bị tràn/che mất nút nào không?

Ghi lại BẤT KỲ chỗ nào app treo, crash, hoặc hiện lỗi — kèm ảnh chụp màn hình.
CHECKLIST
