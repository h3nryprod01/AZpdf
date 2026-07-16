# ADR 0001: MuPDF là engine prototype cho Windows/Linux

- **Trạng thái:** Accepted for prototype
- **Ngày:** 2026-07-17

## Bối cảnh

AZpdf phát hành AGPL-3.0-only, local-first và cần adapter PDF cho Windows/Linux thay thế PDFKit trên macOS. Engine phải render và thao tác PDF cục bộ; không được thêm cloud SDK hay tài khoản.

## Quyết định

Dùng **MuPDF AGPL-3.0** làm engine cho prototype Windows/Linux, thông qua adapter tuân thủ `AZpdfCore.PDFDocumentEngine`.

Lý do:

- MuPDF tự công bố là framework mã nguồn mở, nhẹ, dành cho xem/chuyển đổi PDF, XPS và ebook, đồng thời phát hành AGPL-3.0.
- AGPL của engine phù hợp với AGPL-3.0-only đã chọn cho AZpdf, không đòi hỏi chuyển project sang license yếu hơn.
- Engine được đánh giá ở tầng adapter; core và giao diện không gọi MuPDF trực tiếp.

## Điều kiện trước khi tích hợp

1. Prototype render/open/save trên Windows và Linux phải vượt qua fixture PDF chung.
2. Benchmark render, bộ nhớ và fidelity phải được công bố trong repository.
3. Kiểm tra license của mọi third-party dependency/binary trước khi phân phối.
4. Không build hoặc bật network, telemetry, update checker hay plugin host mặc định.

## Hệ quả

- macOS tiếp tục dùng PDFKit adapter.
- Windows/Linux có thể dùng native UI adapter riêng, nhưng bắt buộc thực thi `DocumentOperation` qua `PDFDocumentEngine`.
- Nếu benchmark không đạt, thay engine chỉ tác động adapter và ADR kế tiếp, không làm đổi contract local-first.

## Nguồn

- [MuPDF repository và AGPL-3.0](https://github.com/ArtifexSoftware/mupdf)
- [MuPDF documentation](https://mupdf.readthedocs.io/en/latest/)
