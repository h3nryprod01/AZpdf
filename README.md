# AZpdf

Trình đọc và chỉnh sửa PDF native cho macOS, mã nguồn mở và đặt quyền riêng tư lên trước.

<img width="254" height="254" alt="Generated image 3" src="https://github.com/user-attachments/assets/53716e43-aa4a-4f71-ae2f-37f782328eb2" />


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
- Chèn ảnh trực tiếp lên trang PDF; kéo để di chuyển, đổi kích thước qua Inspector và lưu thành stamp annotation bền vững
- Xuất trang hiện tại thành một PDF riêng biệt
- Mở PDF được bảo vệ bằng mật khẩu bằng prompt native trên máy
- OCR trang hiện tại hoặc toàn bộ tài liệu theo pipeline hybrid local-first: ưu tiên text layer PDF, Vision 3× cho trang scan; xem, sửa, sao chép hoặc xuất kết quả `.txt`
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
- CI kiểm tra source để chặn API client mạng trong app/core.
- **Plugin-ready:** OCR, dịch và tóm tắt sẽ là plugin cài đặt tùy chọn; bản thân AZpdf không phụ thuộc dịch vụ cloud.
- Plugin chỉ được phát hiện cục bộ tại `~/Library/Application Support/AZpdf/Plugins/`; xem [Plugins/README.md](Plugins/README.md).

## Ủng hộ

AZpdf miễn phí theo AGPL-3.0. Nếu dự án hữu ích, bạn có thể [ủng hộ tác giả qua Ko-fi](https://ko-fi.com/h3nryng).

Hoặc quét VietQR để ủng hộ trực tiếp tại Việt Nam:

<img src="Assets/donate-vietqr.jpg" alt="VietQR ủng hộ AZpdf" width="280" />

## Phát triển
Yêu cầu macOS 14+ và Xcode 26. Chạy `./script/build_and_run.sh`; CI dùng `./script/build_and_run.sh --bundle` để chỉ tạo `.app`, không mở GUI. Khi chạy từ mã nguồn, cài thêm MuPDF (`brew install mupdf`) để dùng chèn ảnh. Bản phát hành phải truyền `MUTOOL_RUNTIME_DIR` chứa MuPDF self-contained, đã kiểm tra giấy phép và tương thích Hardened Runtime; script release sẽ từ chối bundle thiếu runtime.

Đóng gói phát hành dùng Developer ID Application, Hardened Runtime và notarization; xem [hướng dẫn release macOS](docs/MACOS_RELEASE.md). Bản v1 hỗ trợ chữ ký số CMS/PKCS#7 tách rời (`.p7s`) bằng certificate trong Keychain; PDF gốc không bị sửa.

Lộ trình kỹ thuật và chuẩn bị Windows/Linux: [ROADMAP.md](ROADMAP.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Quy ước plugin cục bộ: [docs/PLUGIN_PROTOCOL.md](docs/PLUGIN_PROTOCOL.md).

Định hướng OCR local-first: [docs/OCR_PLAN.md](docs/OCR_PLAN.md).

## License

AGPL-3.0-only. AZpdf luôn miễn phí để sử dụng, chia sẻ và cải tiến; các bản phân phối đã sửa đổi cũng phải công khai mã nguồn theo cùng giấy phép. Xem [văn bản AGPL-3.0 chính thức](https://www.gnu.org/licenses/agpl-3.0.html).
