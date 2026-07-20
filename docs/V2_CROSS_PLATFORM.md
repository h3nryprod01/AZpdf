# AZpdf v2 — Definition of Done đa nền tảng

## Mục tiêu

AZpdf v2 cung cấp cùng một hành vi đọc, chỉnh sửa và lưu PDF trên macOS, Windows và Linux. UI có thể khác theo nền tảng, nhưng file đầu ra và quy tắc an toàn phải được kiểm chứng bằng cùng fixture và contract tests.

## Kiến trúc đã chốt

- `AZpdfCore`: Foundation-only, không import PDFKit/AppKit/SwiftUI/WinSDK.
- `PDFDocumentEngine`: lifecycle mở, lưu và thao tác.
- `PDFDocumentReadingEngine`: metadata, trang, text, annotation và render.
- `PortableDocumentSession`: modified state, undo/redo và rollback khi engine lỗi.
- `PDFEngineCapabilities`: UI chỉ bật tính năng engine đã triển khai.
- macOS: PDFKit adapter trong giai đoạn chuyển tiếp.
- Windows/Linux: MuPDF theo AGPL-3.0, sau benchmark và audit dependency.
- Windows/Linux UI: Flutter desktop; giao tiếp với Swift core qua `azpdf-engine` JSON v1 để giữ engine sandboxable và không nhân đôi logic PDF trong Dart.

## Cổng chất lượng bắt buộc

1. **Tính đúng PDF**
   - Mở/lưu round-trip không mất page tree, metadata, outline, form hoặc annotation ngoài phạm vi chỉnh sửa.
   - Render comparison trên fixture chung; sai khác phải có threshold và ảnh diff lưu trong CI artifact.
   - Password, malformed PDF và file dung lượng lớn phải fail an toàn, không crash.

2. **Chuẩn tài liệu**
   - Parser/writer ưu tiên PDF 2.0 (ISO 32000-2).
   - Validation workflow cho PDF/A-4 và PDF/UA-2; không tự tuyên bố compliant nếu chưa qua validator độc lập.
   - Chữ ký số theo PAdES; integrity và certificate trust luôn báo riêng.

3. **Khả năng truy cập**
   - Keyboard-only cho mọi flow chính, focus order xác định và tên điều khiển đầy đủ.
   - Screen reader: VoiceOver, Narrator và Orca.
   - Kiểm tra PDF/UA tập trung structure tree, reading order, alt text, table headers và language metadata.

4. **OCR local-first**
   - OCR tạo text layer có bounding box và confidence, không chỉ trả plain text.
   - Layout analysis giữ paragraph, columns, table, image region và công thức khi engine hỗ trợ.
   - Luôn có review/correction trước khi ghi lại PDF; không gửi tài liệu ra mạng mặc định.
   - Layout portable phải ghi rõ coordinate space để tránh đảo trục khi chuyển giữa PDFKit và MuPDF.

5. **Bảo mật và chuỗi cung ứng**
   - Không analytics, tài khoản hoặc network client trong app lõi.
   - SBOM cho từng gói phát hành; dependency và license audit trong CI.
   - Fuzz parser boundary, giới hạn memory/CPU, sandbox worker cho OCR/plugin.
   - Ký gói theo nền tảng: notarization macOS, Authenticode Windows, checksum/signature Linux.

## Các mốc triển khai

### M1 — Portable engine contract

- [x] Model hình học, metadata, page, annotation, render và capability.
- [x] Session portable với undo/redo, rollback và modified state.
- [x] PDFKit adapter đọc metadata/page/text/annotation/render.
- [x] Test lõi trên macOS; khai báo CI Ubuntu và Windows.
- [x] Contract cho outline, form value, encryption và embedded files.
- [x] PDFKit adapter cho outline, form value và security inspection.
- [x] Shared engine conformance harness cho metadata/page/text/annotation/render.
- [ ] Adapter embedded files và thao tác ghi outline.

### M2 — MuPDF prototype

- [x] Pin MuPDF 1.28.0, Swift Subprocess và Swift System; ghi license/notices.
- [x] CLI prototype mở, render, text/structured-layout extraction, search và save byte-preserving.
- [x] Fixture generator và benchmark script cho render, structured text, latency và peak RSS.
- [x] Baseline Ubuntu x86_64 bằng MuPDF 1.28.0; runtime audit, integration test và release build đạt.
- [ ] Benchmark fixture về fidelity, latency, peak memory và output round-trip.
- [ ] Fuzz/sanitizer gate cho C boundary.

Runtime Linux phải qua ELF dependency audit; chỉ system runtime trong `/lib*` hoặc `/usr/lib*` được phép, không chấp nhận dependency mất hoặc đường dẫn từ máy build.

### M3 — Windows/Linux shell

- [x] Scaffold Flutter cho Windows/Linux và engine bridge tự tìm runtime cạnh bundle.
- [x] Linux release: file dialog, tabs có khung, sidebar trang, thumbnail, render, search, zoom, save/save-as, tooltip và keyboard shortcuts.
- [x] Linux bundle tự chứa Swift stdlib + MuPDF 1.28.0; health/ELF dependency audit đạt.
- [x] Annotation editor Linux có text/note/image, move/resize, format, thay ảnh và working-copy Save; đã QA GUI + PDF round-trip trên Ubuntu 24.04.
- [x] Undo/redo snapshot, Save/Discard/Cancel khi đóng tab/cửa sổ và annotation transform 0°/90°/180°/270°; đã QA GUI trên Ubuntu 24.04.
- [x] OCR searchable-PDF baseline trên Linux: OCRmyPDF/Tesseract, Việt/Anh, deskew/rotation, working copy, Save và Undo/Redo; đã QA bằng PDF scan image-only.
- [x] Linux bundle mang OCRmyPDF/Tesseract/Ghostscript/qpdf và pyHanko portable; audit ELF và smoke test Ubuntu container sạch, không mạng đạt.
- [x] Chạy lại release với generator SPDX mới; SBOM/checksum và clean-container smoke đã xác minh trên workstation Ubuntu 24.04.
- [x] Linux PAdES Baseline B sign/verify: PKCS#12 passfile 0600, integrity/trust tách riêng, phát hiện tamper và undo working copy.
- [x] `DocumentIR` v1 portable: schema/version, geometry top-left, provenance, reading order, word quad, style, bảng, công thức, figure/alt text và relation validation.
- [x] JSON CLI không phụ thuộc MuPDF để validate `DocumentIR` và xuất plain text theo reading order; có fixture provider-neutral.
- [x] Structured OCR provider contract v1 khai báo local CPU/GPU, model/SPDX license, language/feature và giới hạn trang/VRAM; request được validate trước khi chạy.
- [x] MuPDF structured text → `DocumentIR` baseline và CLI generate/validate/export-text; smoke test PDF thường + trang xoay đạt.
- [x] Flutter review `DocumentIR`: overlay block top-left, reading order, geometry/confidence, provenance và copy text; widget test + visual QA engine Release thật đạt.
- [x] Structured OCR process adapter fail-closed; Linux Bubblewrap cô lập network/filesystem theo invocation và phân loại AppArmor/user-namespace failure thành `sandboxUnavailable`.
- [x] Runner Flatpak fail-closed: `flatpak-spawn --sandbox --no-network`, provider bắt buộc dưới `/app`, input/request read-only, output directory riêng, không `--host`; 5/5 Linux unit tests đạt.
- [x] Flatpak development manifest + Freedesktop 25.08, sandbox probe E2E và GTK portal `Ctrl+O` mở/render PDF fixture thật đã đạt trên Ubuntu 24.04; manifest không có network hoặc host/home filesystem.
- [ ] Chuyển Flatpak manifest sang reproducible build từ source để gửi Flathub; kiểm tra portal Open/Save As trên KDE thật. Gói hệ thống vẫn cần AppArmor profile nếu dùng Bubblewrap trực tiếp.
- [ ] Provider layout nâng cao ánh xạ vào `DocumentIR`; PAdES B-T và LT/LTA với TSA/OCSP/CRL production.
- [ ] Recent files, drag/drop, restore session và kiểm thử Windows release thật.
- [ ] Keyboard nudge cho annotation đạt parity macOS.
- [ ] Accessibility audit Narrator/Orca và high-contrast mode.
- [ ] Installer/updater không yêu cầu tài khoản và không thu telemetry.

### M4 — Parity và phát hành

- [ ] Cùng fixture/conformance suite trên cả ba hệ điều hành.
- [ ] OCR structured-layout, PAdES verify/sign, redact phá hủy và form workflow đạt parity trên cả ba hệ điều hành.
- [ ] Gói phát hành có SBOM, chữ ký/checksum, privacy statement và reproducible build notes.
