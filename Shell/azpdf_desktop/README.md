# AZpdf desktop shell

Flutter shell cho Windows/Linux, giao tiếp với portable Swift engine qua JSON CLI `azpdf-engine`.

## Runtime

- Flutter 3.44+
- `azpdf-engine` và `mutool` đặt cạnh executable shell
- OCR tùy chọn: `ocrmypdf` trong `PATH`, biến `AZPDF_OCRMYPDF`, hoặc `runtime/ocrmypdf/ocrmypdf` cạnh engine
- PAdES tùy chọn: `pyhanko` trong `PATH`, biến `AZPDF_PYHANKO`, hoặc `runtime/pyhanko/pyhanko` cạnh engine
- Tesseract language data: `vie`, `eng`, `osd`

## Kiểm tra

```bash
flutter pub get
flutter analyze
flutter test
```

Build Linux từ root repository:

```bash
MUTOOL_BIN=/path/to/mutool \
FLUTTER_BIN=/path/to/flutter \
script/build_linux_release.sh
```

Muốn bundle release tự chứa, đặt cả hai biến:

```bash
OCRMY_PDF_RUNTIME_DIR=/path/to/portable-ocrmypdf \
PYHANKO_RUNTIME_DIR=/path/to/portable-pyhanko \
MUTOOL_BIN=/path/to/mutool \
FLUTTER_BIN=/path/to/flutter \
script/build_linux_release.sh
```

`build_ocrmypdf_runtime.sh` trên Linux freeze OCRmyPDF, copy Tesseract,
Ghostscript/qpdf, `vie`/`eng`/`osd`, ICC profiles và dependency ELF. Không chỉ
copy `/usr/bin/ocrmypdf`. `build_pyhanko_runtime.sh` freeze pyHanko cùng
`certifi` CA bundle và `tzdata`; mật khẩu PKCS#12 vẫn đi qua passfile 0600.

Release build clean Swift scratch cache, chạy analyzer/widget tests, audit
runtime, health checks và tạo `AZpdf-Linux-SBOM.spdx` cùng SHA-256 cạnh bundle.

Development Flatpak dùng Freedesktop 25.08:

```bash
script/build_flatpak_dev.sh
script/test_flatpak_sandbox.sh
AZPDF_FLATPAK_TEST_PDF=/path/to/basic.pdf \
AZPDF_FLATPAK_EXPECT_TEXT='AZpdf engine fixture' \
script/test_flatpak_gui.sh
```

Manifest development stage bundle Release local đã QA; chưa phải manifest
reproducible từ source để gửi Flathub. GUI harness chạy Xvfb biệt lập, kiểm tra
`Ctrl+O`, document portal, render thật và OCR screenshot. Test portal trên phiên
desktop thật yêu cầu opt-in rõ ràng để tránh chụp nội dung riêng tư.

## DocumentIR cho OCR layout

Provider OCR nâng cao ghi JSON theo `DocumentIR` v1. Engine có thể validate và
trích plain text theo reading order mà không cần MuPDF:

```bash
azpdf-engine ir-baseline --document input.pdf --output document-ir.json
azpdf-engine ir-validate --input document-ir.json
azpdf-engine ir-export-text --input document-ir.json --output document.txt
```

`ir-baseline` ánh xạ structured text MuPDF hiện có thành paragraph/figure IR;
provider nâng cao sẽ enrich hoặc thay thế block thành table/formula/semantic
reading order. Mapping baseline đã test cả PDF thường và trang xoay.

Nút **Review bố cục và reading order** tạo IR cho trang hiện tại, hiển thị danh
sách block theo thứ tự đọc, overlay geometry/confidence trên bản render và cho
copy plain text. MuPDF baseline được gắn nhãn riêng với provider layout nâng cao.

Provider process production phải chạy qua OS sandbox có network isolation.
Linux runner dùng Bubblewrap và fail-closed nếu AppArmor/user namespace chặn
bootstrap; không tự chạy lại provider ở chế độ unsandboxed. Bản Flatpak dùng
`flatpak-spawn --sandbox --no-network`, chỉ chạy provider đóng gói dưới `/app`,
expose input/request read-only và một output directory riêng; cấm `--host`.
Probe E2E trên Ubuntu 24.04 đã xác nhận network/host bị chặn và write ngoài
output không tồn tại bền vững.

Fixture liên thông nằm tại `Tests/Fixtures/document-ir-v1.json`. Input bị giới
hạn 256 MiB và phải qua schema version, geometry, confidence, payload và semantic
reference validation trước khi UI/exporter sử dụng.
