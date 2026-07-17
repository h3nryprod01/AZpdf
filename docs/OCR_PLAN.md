# Brainstorm OCR local-first cho AZpdf

## Đã có trong macOS v1

OCR trang hiện tại hoặc toàn bộ tài liệu dùng pipeline hybrid local-first: ưu tiên text layer vốn có trong PDF để không mất nội dung/reading order; nếu không có text layer đủ nghĩa thì dùng Vision nhận dạng Việt/Anh ở 3× resolution. Có tiến độ theo trang và nhãn nguồn kết quả. Người dùng review, sửa, sao chép hoặc xuất `.txt`; AZpdf không tự ghi text layer vào PDF.

## Mục tiêu v1.1

OCR hoàn toàn trên máy, không tải PDF hay ảnh lên cloud. Người dùng chọn trang hoặc vùng cần nhận dạng, xem trước văn bản, rồi mới quyết định thêm text layer hoặc xuất `.txt`/`.md`.

## Lộ trình đề xuất

1. **macOS — Vision framework:** dùng `VNRecognizeTextRequest`, hỗ trợ Việt/Anh, xử lý từng trang và hiển thị tiến độ/hủy tác vụ.
2. **Review trước khi ghi:** kết quả là bản nháp có bounding box; người dùng sửa text trước khi thêm annotation/text layer vào PDF.
3. **Xuất dữ liệu:** copy clipboard, `.txt`, `.md`, hoặc thêm searchable text layer vào bản sao PDF.
4. **Kiến trúc portable:** đưa request/result OCR vào `AZpdfCore`; adapter Vision là macOS-specific.
5. **Windows/Linux:** plugin local được ký/xác minh và chạy qua XPC/sandbox tương đương; có thể dùng Tesseract hoặc PaddleOCR, không gửi dữ liệu ra mạng.

## Điều cần quyết định trước khi code

- Ưu tiên tốc độ hay độ chính xác với tiếng Việt và tài liệu scan mờ?
- OCR toàn trang hay chọn vùng là mặc định?
- Kết quả nên thêm overlay có thể tìm kiếm hay chỉ xuất text? Khuyến nghị: chọn vùng mặc định, overlay là tùy chọn sau khi review.

## Ranh giới an toàn

- Không tự chạy OCR khi mở PDF.
- Không gửi ảnh/PDF/recognized text/telemetry ra Internet.
- Luôn làm việc trên bản sao trong bộ nhớ; ghi vào PDF chỉ sau xác nhận của người dùng.
