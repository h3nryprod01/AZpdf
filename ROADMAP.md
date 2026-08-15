# Roadmap AZpdf

## Trạng thái kiểm chứng (2026-08-08)

- **v1.3.1 đã phát hành cho cả ba nền tảng** — macOS (ký Developer ID + notarize + staple,
  `spctl` trả `Notarized Developer ID` kể cả khi gắn cờ quarantine), Linux (AppImage, `health` và
  `ocr-health` đều `ok:true` trong container Ubuntu 24.04 trắng), Windows (gói portable, chưa ký;
  `azpdf-engine.exe health` `ok:true` trên Windows 11 thật **và** trên máy CI không cài Swift sau
  khi giải nén ở thư mục khác). SHA-256 của cả ba đối chiếu được từ chính trang release.
- **217 test / 7 skip / 0 fail.** CI 7 job xanh.
- **Thêm lưới pixel-diff render** (`script/pixel_diff.sh`, chỉ macOS): 217 unit test không thấy
  một pixel nào, đây là thứ duy nhất bắt được "render đổi". **Ngưỡng tỉ lệ đầu tiên đã bị đo là
  sai và gỡ bỏ**: `>0,1% pixel` để lọt cả ảnh dịch 2 px (0,011%) lẫn hai trang nội dung khác hẳn
  (0,034%) — vì trang A4 chữ đen nền trắng có ~99,97% pixel trắng nên tỉ lệ không bao giờ chạm
  ngưỡng. Nay không có ngưỡng tỉ lệ: FAIL nếu **bất kỳ** pixel nào lệch quá 8/255. Luật cập nhật
  baseline: [qa-report/pixel-diff-baseline-policy.md](qa-report/pixel-diff-baseline-policy.md).
  *Nối tiếp hai bài học cũ: gate không tự chứng minh được là gate không đáng tin.*
- **Đính chính hai khẳng định trong bản 2026-07-27 bên dưới** — cả hai đã lạc hậu, giữ nguyên
  văn để thấy chúng sai ở đâu:
  - *"hiệu năng file lớn vẫn chưa ai đo"* → **đã đo**, xem
    [qa-report/perf-and-security-2026-07-31.md](qa-report/perf-and-security-2026-07-31.md).
  - *"Windows: bootstrap trong VM báo thiếu toolchain"* → **hết hiệu lực**. Windows chạy đủ bộ
    test core trong CI và đã có gói phát hành.

## Trạng thái kiểm chứng (2026-07-27)

- **183 test / 7 skip / 0 fail.** Ba gate CI xanh: `audit_i18n_strings`, `audit_local_first`,
  `audit_portable_core`.
- **i18n xong:** en + vi, 361 key mỗi bảng, chọn ngôn ngữ trong Settings áp dụng ngay.
- **In ấn xong:** `⌘P`, có test end-to-end chạy headless (`jobDisposition = .save`).
- **Đính chính một khẳng định cũ về accessibility.** Bản kế hoạch nâng cấp từng ghi *"1 modifier
  accessibility trong cả app → 17 icon toolbar là 17 nút vô nghĩa với VoiceOver"*. Sai. Đếm modifier
  `accessibility*` là thước đo sai: SwiftUI tự suy nhãn từ `Label(text, systemImage:)` và từ
  `VStack{Image; Text}`. Đo thật bằng AX API trên app đang chạy: 47 control, 6 không nhãn — **cả 6
  đều là scrollbar/traffic-light của AppKit**. Chi tiết + 2 lỗi a11y thật tìm được nhờ phép đo:
  [qa-report/azpdf-macos-a11y-i18n-2026-07-27.md](qa-report/azpdf-macos-a11y-i18n-2026-07-27.md).
  *Bài học nối tiếp bài học 2026-07-21: unit test xanh ≠ tính năng chạy, và **đếm modifier ≠ đo được**.*
- **Còn lại ở nhóm chặn đường: hiệu năng file lớn vẫn chưa ai đo.** Benchmark duy nhất là 3 fixture
  1 trang; thumbnail sidebar vẫn render đồng bộ trong view body.

## Trạng thái kiểm chứng (2026-07-21)

> Kỷ luật: chỉ giữ `[x]` khi có **bằng chứng chạy ở tầng UI/e2e**, không dựa vào unit test xanh.
> Trong phiên QA này phát hiện 3 mục từng `[x]` nhưng thực tế hỏng khi lái GUI (search, zoom thủ công,
> chữ ký tay không render) — cả 3 đã vá và nay có test canh. Bài học: unit test xanh ≠ tính năng chạy.

- **macOS:** 25/25 tính năng README đã lái GUI thật — xem [qa-report/README-COVERAGE.md](qa-report/README-COVERAGE.md). Search/zoom/chữ ký đã vá + ghim bằng test (`SignaturePointTests`, `MuPDFAnnotationKindTests`).
- **Linux (shell Flutter):** đọc/render/thumbnail/tab/điều hướng/search đã verify GUI thật trên Ubuntu 24.04 — xem [qa-report/azpdf-linux-shell-gui-2026-07-21.md](qa-report/azpdf-linux-shell-gui-2026-07-21.md). Lưu ý: annotation cần mutool ≥ 1.24 (bundle release mang 1.28); build-từ-source với mutool apt 1.23 sẽ lỗi JS.
- **Windows:** roadmap — chạy bootstrap trong VM báo thiếu toolchain (Swift for Windows + VS Build Tools). Đúng mức cam kết README.

## Hoàn thành trên macOS

- [x] Reader/editor local-first: tabs, search, outline, page tools, annotations, signature tay
- [x] In tài liệu (`⌘P`) qua `PDFDocument.printOperation`; annotation in ra, trang xoay in đúng chiều
- [x] Chèn hình: chữ nhật, tròn, đường kẻ, mũi tên, sao, tam giác — mỗi hình là subtype PDF thật nên renderer khác vẽ được
- [x] Chỉnh sửa chú thích trực tiếp trên đối tượng: khung chọn, tay cầm resize, popover neo vào đối tượng
- [x] Bảo mật cơ bản: mật khẩu, form widgets, redact phá hủy
- [x] Plugin discovery cục bộ với protocol versioning
- [x] OCR local-first trang hiện tại qua Vision framework: review, sao chép và xuất text
- [x] OCR toàn bộ và xuất PDF mới có searchable text layer sau review (OCRmyPDF local; runtime release cần language data)
- [x] OCR chọn vùng trực tiếp trên trang với preview/review cục bộ
- [ ] Hiệu chỉnh bounding boxes và text theo vùng trước khi tạo searchable PDF

## Trước v1.0

- [x] Chữ ký CMS/PKCS#7 tách rời dựa trên certificate trong Keychain (PDF gốc không bị sửa)
- [x] Nhúng PAdES Baseline B vào PDF từ PKCS#12 và kiểm tra integrity/certificate trong app
- [x] Chọn profile PAdES Baseline B/LT/LTA; LT/LTA yêu cầu TSA URL và nhúng validation info qua pyHanko
- [ ] Kiểm thử PAdES-LT/LTA với TSA, OCSP/CRL và trust store production; không tuyên bố long-term validation nếu provider chưa xác minh
- [ ] Wasm plugin worker local, cấp quyền theo tài liệu; XPC App-Sandbox chỉ cho worker do AZpdf phát hành (discovery/validation đã có; chưa thực thi plugin)
- [x] Localization en/vi (`.lproj` + helper `L(_:)`, 361 key mỗi bảng, parity có test canh); chọn ngôn ngữ trong Settings áp dụng ngay không cần khởi động lại; CI gate `audit_i18n_strings.sh` chặn chuỗi hardcode mới
- [x] Accessibility/VoiceOver audit — đo bằng AX API trên app đang chạy: mọi control do AZpdf viết đều có nhãn đọc được; chỉ scrollbar/traffic-light của AppKit là không, và VoiceOver tự xử lý theo subrole
- [x] Fixture PDFs và regression rendering pixel-diff — xong phần render một chiều (xem nhóm
      Windows/Linux); phần round-trip vẫn còn mở ở đó, không lặp lại ở đây nữa
- [x] Script đóng gói Hardened Runtime, signing và notarization có kiểm tra đầu vào
- [x] Ký Developer ID, notarize và staple ZIP macOS; Gatekeeper đã xác minh `Notarized Developer ID`
- [x] Tạo GitHub Release public và upload ZIP notarized

## Windows và Linux

- [x] Tách portable core Foundation-only (`AZpdfCore`) cho policy, plugin manifest và intent thao tác
- [x] Đưa adapter PDFKit macOS qua contract `PDFDocumentEngine`
- [x] Thêm model đọc/render/metadata/annotation độc lập nền tảng và `PortableDocumentSession` với undo/redo
- [x] Thêm capability contract để UI chỉ hiện tính năng engine thực sự hỗ trợ
- [ ] Mở rộng portable core để mô hình hóa toàn bộ đọc/lưu/chỉnh sửa độc lập PDFKit
      — đã có số đo làm căn cứ: [ma trận operation-conformance](qa-report/engine-operation-matrix-2026-07.md)
      cho thấy PDFKit làm 6/17 case `DocumentOperation`, MuPDF 3/17, **giao nhau = 0**
- [x] Quyết định engine prototype qua ADR về giấy phép và kiến trúc (MuPDF AGPL)
- [x] Benchmark baseline latency/memory MuPDF 1.28.0 trên macOS arm64 và Ubuntu x86_64
- [x] Pixel-diff regression cho render macOS: 4 fixture ở 144 DPI, gate 0-pixel, có self-test
      cấy lệch 2 px chạy trước mỗi lần so
- [ ] Mở rộng pixel-diff sang round-trip và bộ PDF thực tế/malformed
- [ ] Dựng AppImage **trong CI** — hiện dựng tay, đã khiến Linux tụt lại 1.2.0 một lần khi
      macOS/Windows lên 1.3.0
- [x] Khai báo CI cho portable core trên macOS, Ubuntu và Windows
- [x] Dựng Flutter shell Windows/Linux và JSON bridge `azpdf-engine`
- [x] Chạy Linux release với open/render/thumbnails/tabs/search/zoom/save, tooltip và phím tắt
- [x] Linux annotation baseline: text/note/image, move/resize, format, thay ảnh, working copy và Save
- [x] Linux undo/redo bằng snapshot working PDF, cảnh báo chưa lưu và mapping annotation cho trang xoay
- [x] Linux OCR searchable-PDF baseline: Việt/Anh, deskew/rotation, Save và Undo/Redo; QA PDF scan image-only đạt
- [x] Đóng gói OCRmyPDF/Tesseract/Ghostscript/qpdf và pyHanko portable trong Linux bundle; audit ELF và smoke test container sạch, tắt mạng đạt
- [x] Thêm `DocumentIR` portable v1 cho reading order, bảng, công thức, figure/alt text, provenance và geometry top-left có validation
- [x] Thêm capability/request contract v1 cho structured OCR provider local CPU/GPU, model license, language, feature và resource limit
- [x] Ánh xạ MuPDF structured text thành `DocumentIR` baseline; CLI generate/validate/export-text và geometry trang xoay đã test
- [x] Thêm viewer `DocumentIR` trong Flutter: overlay block, reading order, geometry/confidence và copy text; QA bằng engine Release thật trên Ubuntu
- [ ] Thêm provider structured-layout và editor sửa text/bảng/công thức/reading order trước export
- [x] Linux shell ký/xác minh PAdES Baseline B, tách integrity/trust và hỗ trợ undo working copy
- [x] Đóng gói pyHanko vào bản phát hành Windows và kiểm thử release thật trên Windows 11
      (`azpdf-engine.exe health` `ok:true`; gói portable v1.3.1)
- [ ] **Ký PAdES thật trên Windows** — CI mới chỉ chạy `pyhanko.exe --version`, chưa từng ký
      một tài liệu nào trên nền tảng đó
- [ ] OCR runtime trên Windows — **hoãn có chủ đích**, không phải bỏ sót: Tesseract/Ghostscript/qpdf
      ở đó đều installer-based, chưa có công thức portable (xem `.claude/memory/decisions.md`)
- [x] Chạy cùng **fixture** conformance trên cả ba nền tảng (`azpdf-engine selftest` ở
      `linux-core` và `windows-core`; macOS chạy fixture đó qua test suite)
- [ ] Đưa **cùng một harness** cho cả ba — hiện đối xứng về fixture, chưa đối xứng về cách chạy

Definition of Done chi tiết: [docs/V2_CROSS_PLATFORM.md](docs/V2_CROSS_PLATFORM.md).
