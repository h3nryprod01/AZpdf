# Roadmap AZpdf

## Hoàn thành trên macOS

- [x] Reader/editor local-first: tabs, search, outline, page tools, annotations, signature tay
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
- [ ] Accessibility/VoiceOver audit, localization, fixture PDFs và regression rendering
- [x] Script đóng gói Hardened Runtime, signing và notarization có kiểm tra đầu vào
- [x] Ký Developer ID, notarize và staple ZIP macOS; Gatekeeper đã xác minh `Notarized Developer ID`
- [x] Tạo GitHub Release public và upload ZIP notarized

## Windows và Linux

- [x] Tách portable core Foundation-only (`AZpdfCore`) cho policy, plugin manifest và intent thao tác
- [x] Đưa adapter PDFKit macOS qua contract `PDFDocumentEngine`
- [x] Thêm model đọc/render/metadata/annotation độc lập nền tảng và `PortableDocumentSession` với undo/redo
- [x] Thêm capability contract để UI chỉ hiện tính năng engine thực sự hỗ trợ
- [ ] Mở rộng portable core để mô hình hóa toàn bộ đọc/lưu/chỉnh sửa độc lập PDFKit
- [x] Quyết định engine prototype qua ADR về giấy phép và kiến trúc (MuPDF AGPL)
- [x] Benchmark baseline latency/memory MuPDF 1.28.0 trên macOS arm64 và Ubuntu x86_64
- [ ] Mở rộng benchmark fidelity bằng pixel diff, round-trip và bộ PDF thực tế/malformed
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
- [ ] Build OCR/PAdES runtime và kiểm thử release thật trên Windows
- [ ] Chạy cùng fixture và conformance tests với macOS

Definition of Done chi tiết: [docs/V2_CROSS_PLATFORM.md](docs/V2_CROSS_PLATFORM.md).
