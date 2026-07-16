# Kiến trúc AZpdf

## Mục tiêu

AZpdf là trình đọc/chỉnh sửa PDF local-first, miễn phí và AGPL-3.0-only. macOS là bản phát hành đầu tiên; kiến trúc không được gắn chính sách sản phẩm vào PDFKit để có thể hỗ trợ Windows và Linux.

## Ranh giới nền tảng

| Lớp | Trách nhiệm | macOS hiện tại | Windows/Linux sau này |
| --- | --- | --- | --- |
| Product policy | Local-first, quyền plugin, undo, hành vi file | Swift models/stores | Dùng lại đặc tả và test hành vi |
| PDF engine adapter | Render, selection, annotation, form, export | PDFKit | Adapter engine riêng theo nền tảng |
| Native UI | Tabs, sidebar, phím tắt, panel | SwiftUI + AppKit | UI native hoặc cross-platform adapter |
| Plugin host | Khám phá manifest, quyền truy cập, IPC local | `PluginRegistry` (discovery) | Cùng protocol v1 |

`AZpdfCore` là module Foundation-only chứa policy local-first, plugin manifest và intent thao tác tài liệu. `DocumentStore` còn là adapter macOS vì dùng `PDFDocument`/`NSImage`; nó ghi nhận `DocumentOperation` từ core, nhưng việc render/persist thuộc về PDFKit. Windows/Linux sẽ thay adapter PDFKit, giữ nguyên core contract và tests.

## Bất biến local-first

1. Không có network client, analytics hoặc tài khoản trong ứng dụng lõi.
2. Mở/lưu/xuất chỉ dùng panel và filesystem do người dùng chọn.
3. Plugin không tự tải, không tự cập nhật và không được cấp PDF nếu chưa có thao tác chủ động của người dùng.
4. Redact vĩnh viễn phải tạo dữ liệu PDF mới, không chỉ thêm overlay có thể xóa.

CI chạy `script/audit_local_first.sh` để từ chối `URLSession`, socket và WebSocket client trong App/Core/Services/Stores. Link mở trình duyệt do người dùng nhấp (ví dụ Buy Me a Coffee) không phải PDF transmission và không nằm trong gate này.

CI cũng chạy `script/audit_portable_core.sh` để từ chối PDFKit, AppKit, SwiftUI, UIKit và WinSDK trong `Core/`.

## Lộ trình tương thích

1. Mở rộng `AZpdfCore` với model thao tác trang/annotation độc lập UI.
2. Chọn và triển khai PDF engine adapter cho Windows/Linux qua ADR công khai, sau kiểm tra giấy phép và fidelity PDF.
3. Dùng cùng fixture PDF và behavioral tests trên cả ba nền tảng.
4. Chỉ phát hành plugin host khi sandbox, cấp quyền theo tài liệu và audit log cục bộ đã sẵn sàng.

ADR hiện tại: [0001 - MuPDF prototype cho Windows/Linux](adr/0001-cross-platform-pdf-engine.md).
