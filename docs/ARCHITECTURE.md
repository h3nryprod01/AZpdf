# Kiến trúc AZpdf

## Mục tiêu

AZpdf là trình đọc/chỉnh sửa PDF local-first, miễn phí và AGPL-3.0-only. macOS là bản phát hành đầu tiên; kiến trúc không được gắn chính sách sản phẩm vào PDFKit để có thể hỗ trợ Windows và Linux.

## Ranh giới nền tảng

| Lớp | Trách nhiệm | macOS hiện tại | Windows/Linux sau này |
| --- | --- | --- | --- |
| Product policy | Local-first, quyền plugin, undo, hành vi file | Swift models/stores | Dùng lại đặc tả và test hành vi |
| PDF engine adapter | Render, selection, annotation, form, export | PDFKit | Adapter engine riêng theo nền tảng |
| Desktop UI | Tabs, sidebar, phím tắt, panel | SwiftUI + AppKit | Flutter desktop 3.44 |
| Plugin host | Khám phá manifest, quyền truy cập, IPC local | `PluginRegistry` (discovery) | Cùng protocol v1 |

`AZpdfCore` là module Foundation-only chứa policy local-first, plugin manifest, model dữ liệu PDF và intent thao tác tài liệu. `PDFDocumentEngine` định nghĩa lifecycle đọc/lưu/chỉnh sửa; `PDFDocumentReadingEngine` bổ sung metadata, page descriptor, text, annotation và render. `PDFEngineCapabilities` là nguồn sự thật để UI bật/tắt công cụ theo engine.

`PortableDocumentSession` sở hữu lifecycle tài liệu, trạng thái modified và undo/redo bằng byte snapshot. `DocumentStore` hiện vẫn là adapter macOS vì dùng `PDFDocument`/`NSImage`; quá trình chuyển đổi sẽ đưa dần hành vi sang session chung. Windows/Linux thay PDFKit bằng adapter MuPDF nhưng dùng lại model, session và behavioral tests.

`DocumentIR` là boundary Foundation-only giữa OCR/layout provider và UI/exporter. Schema v1 dùng PDF point với gốc top-left trên trang đã normalize rotation; lưu provenance model, reading order, word quad, style, table span, LaTeX/MathML, figure/alt text và relation giữa block. Provider nâng cao phải ánh xạ kết quả vào IR và qua validation trước khi UI review hoặc exporter tạo searchable/tagged PDF; UI không phụ thuộc trực tiếp schema riêng của PaddleOCR, Docling hay MinerU.

`StructuredOCRProcessProvider` dùng capability handshake + request/output file có giới hạn dung lượng, kiểm tra regular file, provenance, page set và `DocumentIR` validation. Production mặc định từ chối runner không khai báo network isolation. Linux có hai runner fail-closed: Bubblewrap cho gói hệ thống có AppArmor profile phù hợp, và `flatpak-spawn --sandbox --no-network` cho provider được đóng gói dưới `/app`. Runner Flatpak stage input/request vào instance sandbox, expose riêng từng file ở chế độ read-only và chỉ cấp ghi cho một output directory; không bao giờ dùng `--host`. Việc có executable sandbox không đủ để coi runtime sẵn sàng: lỗi namespace/AppArmor/portal luôn trả `sandboxUnavailable`, không fallback unsandboxed.

Development Flatpak dùng Freedesktop 25.08 đã qua probe subsandbox, runtime health và GTK file-portal E2E trên Ubuntu 24.04. Manifest public vẫn phải build reproducible từ source; gói development stage prebuilt Release bundle và không được xem là Flathub-ready.

`azpdf-engine` là executable bridge JSON version 1 dùng chung Windows/Linux. Shell Flutter gửi intent đọc (`health`, `info`, `render`, `text`, `search`, `annotations`), lưu và chỉnh sửa annotation (`upsert-annotation`, `upsert-image-annotation`, `remove-annotation`); response render mang cả crop box và rotation để UI đổi tọa độ PDF ↔ viewport trên trang xoay. Lệnh `ir-validate` và `ir-export-text` hoạt động chỉ với `AZpdfCore`, không yêu cầu MuPDF, để worker OCR/layout trao đổi IR qua file JSON đã validate. Mọi parse/render PDF vẫn đi qua `AZpdfCore` + `AZpdfMuPDF`. Linux bundle dùng Swift static stdlib, đặt `azpdf-engine`, `mutool`, OCRmyPDF/Tesseract/Ghostscript/qpdf, pyHanko và SwiftPM annotation resource trong cùng bundle để không phụ thuộc Swift/Python/OCR toolchain trên máy người dùng. Shell giữ working copy và lịch sử snapshot giới hạn 20 bước cho undo/redo. Boundary này cũng là điểm thay bằng sandboxed worker/IPC mà không viết lại UI.

## Bất biến local-first

1. Không có network client, analytics hoặc tài khoản trong ứng dụng lõi.
2. Mở/lưu/xuất chỉ dùng panel và filesystem do người dùng chọn.
3. Plugin không tự tải, không tự cập nhật và không được cấp PDF nếu chưa có thao tác chủ động của người dùng.
4. Redact vĩnh viễn phải tạo dữ liệu PDF mới, không chỉ thêm overlay có thể xóa.

CI chạy `script/audit_local_first.sh` để từ chối `URLSession`, socket và WebSocket client trong App/Core/Services/Stores. Link Ko-fi do người dùng chủ động nhấp chỉ mở trình duyệt ngoài, không truyền PDF và không nằm trong gate này.

CI cũng chạy `script/audit_portable_core.sh` để từ chối PDFKit, AppKit, SwiftUI, UIKit và WinSDK trong `Core/`.

## Lộ trình tương thích

1. Hoàn tất contract thao tác trang/annotation/form/signature độc lập UI.
2. Triển khai adapter MuPDF sau khi benchmark giấy phép, fidelity, hiệu năng và memory safety đạt ngưỡng.
3. Chạy cùng fixture PDF và behavioral tests trên macOS, Windows, Linux.
4. Chỉ phát hành plugin host khi sandbox, cấp quyền theo tài liệu và audit log cục bộ đã sẵn sàng. `AZpdfCore.PluginDocumentGrant` đã định nghĩa grant in-memory theo plugin/capability/document; host phải enforce contract này.

ADR hiện tại: [0001 - MuPDF prototype cho Windows/Linux](adr/0001-cross-platform-pdf-engine.md) và [0002 - Flatpak là hướng sandbox phân phối Linux ưu tiên](adr/0002-linux-sandbox-distribution.md).
