# AZpdf

Trình đọc và chỉnh sửa PDF native cho macOS, mã nguồn mở và đặt quyền riêng tư lên trước.

![Biểu tượng AZpdf](Assets/AZpdf-icon.png)

## Có trong bản đầu
- Mở, đọc, tìm kiếm và điều hướng PDF
- Mở nhiều PDF trong các tab độc lập, không ghi đè tài liệu đang đọc
- Điều hướng trang bằng toolbar, sidebar và phím tắt `⌘[` / `⌘]`
- Hiển thị mục lục/bookmark PDF trong sidebar khi tài liệu có outline
- Zoom vừa trang mặc định, với điều khiển zoom tay và quay lại vừa trang
- Tìm kiếm có số kết quả và điều hướng kết quả trước/sau
- Thumbnail trang, zoom, chọn văn bản
- Thêm ghi chú/highlight theo vùng chữ đang chọn; xoay, xóa, nhân đôi và sắp xếp lại trang
- Thêm hộp văn bản (free-text annotation) qua sheet native
- Vẽ và chèn chữ ký tay thành ink annotation PDF
- Quản lý và xóa các chú thích trên trang qua Inspector, hỗ trợ undo
- Chèn toàn bộ trang từ PDF khác để ghép tài liệu, có thể hoàn tác
- Chèn ảnh thành một trang PDF mới, hỗ trợ undo
- Xuất trang hiện tại thành một PDF riêng biệt
- Mở PDF được bảo vệ bằng mật khẩu bằng prompt native trên máy
- Xuất bản sao PDF được bảo vệ bằng mật khẩu qua Save Panel native
- Redact lựa chọn theo chế độ phá hủy: raster hóa trang và loại bỏ nội dung gốc khỏi luồng PDF
- Phát hiện form PDF; nhập trực tiếp vào trường widget native trong tài liệu
- Undo/redo tối đa 50 thao tác chỉnh sửa trong phiên làm việc
- Hiển thị rõ trạng thái chỉnh sửa chưa lưu trên tiêu đề và Inspector
- Danh sách tối đa 8 tài liệu gần đây để mở lại nhanh
- Kéo và thả PDF trực tiếp vào cửa sổ để mở
- Lưu đè hoặc xuất ra PDF mới

## Quyền riêng tư và plugin

- **Local-first:** AZpdf không tải PDF, nội dung, mật khẩu hoặc lịch sử tài liệu lên máy chủ.
- **Plugin-ready:** OCR, dịch và tóm tắt sẽ là plugin cài đặt tùy chọn; bản thân AZpdf không phụ thuộc dịch vụ cloud.
- Plugin chỉ được phát hiện cục bộ tại `~/Library/Application Support/AZpdf/Plugins/`; xem [Plugins/README.md](Plugins/README.md).

## Phát triển
Yêu cầu macOS 14+ và Xcode 26. Chạy `./script/build_and_run.sh`; CI dùng `./script/build_and_run.sh --bundle` để chỉ tạo `.app`, không mở GUI.

Lộ trình kỹ thuật và chuẩn bị Windows/Linux: [ROADMAP.md](ROADMAP.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Quy ước plugin cục bộ: [docs/PLUGIN_PROTOCOL.md](docs/PLUGIN_PROTOCOL.md).

## License

AGPL-3.0-only. AZpdf luôn miễn phí để sử dụng, chia sẻ và cải tiến; các bản phân phối đã sửa đổi cũng phải công khai mã nguồn theo cùng giấy phép. Xem [văn bản AGPL-3.0 chính thức](https://www.gnu.org/licenses/agpl-3.0.html).
