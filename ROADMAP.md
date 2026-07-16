# Roadmap AZpdf

## Hoàn thành trên macOS

- [x] Reader/editor local-first: tabs, search, outline, page tools, annotations, signature tay
- [x] Bảo mật cơ bản: mật khẩu, form widgets, redact phá hủy
- [x] Plugin discovery cục bộ với protocol versioning

## Trước v1.0

- [ ] Chữ ký số dựa trên certificate do người dùng cung cấp
- [ ] Plugin host sandbox với cấp quyền theo tài liệu
- [ ] Accessibility/VoiceOver audit, localization, fixture PDFs và regression rendering
- [ ] Cập nhật/đóng gói macOS có signing/notarization cho bản phát hành chính thức

## Windows và Linux

- [x] Tách portable core Foundation-only (`AZpdfCore`) cho policy, plugin manifest và intent thao tác
- [x] Đưa adapter PDFKit macOS qua contract `PDFDocumentEngine`
- [ ] Mở rộng portable core để mô hình hóa toàn bộ đọc/lưu/chỉnh sửa độc lập PDFKit
- [ ] Quyết định engine PDF qua ADR về fidelity, performance và giấy phép
- [ ] Xây dựng UI adapter và CI theo nền tảng
- [ ] Chạy cùng fixture và conformance tests với macOS
