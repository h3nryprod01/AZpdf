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
- [ ] PAdES-LT/LTA: TSA, OCSP/CRL, trust store và long-term validation
- [ ] Wasm plugin worker local, cấp quyền theo tài liệu; XPC App-Sandbox chỉ cho worker do AZpdf phát hành (discovery/validation đã có; chưa thực thi plugin)
- [ ] Accessibility/VoiceOver audit, localization, fixture PDFs và regression rendering
- [x] Script đóng gói Hardened Runtime, signing và notarization có kiểm tra đầu vào
- [ ] Ký/notarize bản phát hành chính thức bằng Developer ID Application certificate

## Windows và Linux

- [x] Tách portable core Foundation-only (`AZpdfCore`) cho policy, plugin manifest và intent thao tác
- [x] Đưa adapter PDFKit macOS qua contract `PDFDocumentEngine`
- [ ] Mở rộng portable core để mô hình hóa toàn bộ đọc/lưu/chỉnh sửa độc lập PDFKit
- [x] Quyết định engine prototype qua ADR về giấy phép và kiến trúc (MuPDF AGPL)
- [ ] Benchmark fidelity/performance MuPDF trên fixture chung trước khi tích hợp
- [ ] Xây dựng UI adapter và CI theo nền tảng
- [ ] Chạy cùng fixture và conformance tests với macOS
