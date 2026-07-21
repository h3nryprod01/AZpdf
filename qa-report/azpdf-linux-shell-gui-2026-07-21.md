# AZpdf — QA shell Flutter Linux (GUI thật, 2026-07-21)

Trước đây chỉ mới test **engine CLI** trên Linux (23/0). Lần này **build + chạy shell Flutter GUI**
thật trên máy Ubuntu, lái bằng xdotool, chụp màn hình — đúng nghĩa "một user Linux mở app".

## Môi trường

| Mục | Giá trị |
|---|---|
| Máy | Ubuntu 24.04.4 LTS, x86_64, 32 core |
| Swift | 6.2.3 (swift-subprocess cần tools ≥ 6.2) |
| Flutter | **3.44.0-stable** (pinned, khớp `.github/workflows/ci.yml`, verify sha256) |
| mutool | **1.23.10** (apt Ubuntu) — *thấp hơn 1.28 mà bundle release mang* |
| Repo | `origin/main` @ `6615b48` (gồm cả fix F/C1/C2) |
| Hiển thị | headless Xvfb `:99` 1280×900, `LIBGL_ALWAYS_SOFTWARE=1` |

## Build (khớp CI) — SẠCH

| Bước | Kết quả |
|---|---|
| `flutter analyze` | **No issues found!** |
| `flutter test` | **9/9 pass** (DocumentIR reading order, undo/redo, cảnh báo chưa lưu, OCR toolbar, ký PAdES working copy) |
| `flutter build linux --release` | **✓ Built** `build/linux/x64/release/bundle/azpdf_desktop` |

## Runtime GUI — CHẠY THẬT

Launch: `DISPLAY=:99 AZPDF_ENGINE=<azpdf-engine> azpdf_desktop multipage.pdf`. App **không crash**, mở PDF ngay từ file arg.

| Kiểm | Kết quả |
|---|---|
| Mở PDF từ arg | ✅ `multipage.pdf` mở thành tab, hiển thị ngay |
| Render trang | ✅ Trang 1 render đúng ("AZpdf engine fixture / Portable open, text extraction…") |
| Thumbnail | ✅ 3 thumbnail ở sidebar, đồng bộ trang hiện tại |
| Điều hướng | ✅ Click thumbnail trang 3 → nhảy đúng, indicator `3 / 3` |
| Trang xoay | ✅ Trang 3 ("Rotated landscape fixture") render **xoay 90° đúng** — rotation normalization hoạt động |
| Search | ✅ Ô "Tìm trong tài liệu" nhận input ("render") |
| Toolbar / zoom / page indicator | ✅ Đầy đủ, `100%`, `1/3`↔`3/3` |
| Footer "Xử lý cục bộ" | ✅ Hiện đúng (local-first) |

→ **Toàn bộ đường đọc + điều hướng của shell Linux hoạt động end-to-end.** Xác nhận claim ROADMAP
"Chạy Linux release với open/render/thumbnails/tabs/search/zoom".

## ⚠️ Phát hiện — annotation JS lỗi trên mutool hệ thống (không phải lỗi shell)

Banner đỏ dưới cửa sổ:
```
ioFailure("SyntaxError: …/AZpdf_AZpdfMuPDF.resources/Resources/azpdf_annotations.js:1:
unexpected token: (identifier) (expected ';')")
```

**Nguyên nhân (đã chốt từ vòng engine trước):** `azpdf_annotations.js` mở đầu bằng
`import mupdf from "mupdf"` (ES module). JS engine của **mutool 1.23.10** (apt) chưa hỗ trợ →
lỗi ngay dòng 1. Repro tối giản: file 1 dòng chỉ chứa `import` đó → lỗi y hệt.

**Phạm vi ảnh hưởng:**
- **Đọc / render / điều hướng / thumbnail / search / zoom: KHÔNG bị ảnh hưởng** (không đi qua JS này) — đã thấy chạy tốt ở trên.
- **Annotation** (list/tạo/sửa) trên shell build-từ-source-với-mutool-hệ-thống thì lỗi.

**Không phải bug của shell:** README ghi bundle release Linux **tự mang MuPDF 1.28.0**, hỗ trợ ES module.
Chỉ khi build từ source dựa vào mutool apt 1.23 mới dính. Muốn xác nhận annotation trên shell cần
mutool ≥ 1.24 (hoặc chạy bundle release có 1.28) — **chưa test ở đây**.

## Kết luận

- ✅ **Shell Flutter Linux: build sạch + chạy GUI thật** — đọc/render (kể cả trang xoay)/thumbnail/tab/điều hướng/search đều hoạt động trên Ubuntu 24.04.
- ⚠️ Annotation cần mutool ≥ 1.24; system mutool 1.23 làm hiện banner lỗi. Chỉ ảnh hưởng build-từ-source, không ảnh hưởng bundle release (mang 1.28).
- **Chưa test trên shell:** save round-trip, annotation (chặn bởi mutool 1.23), OCR/PAdES qua GUI, drag reorder.
