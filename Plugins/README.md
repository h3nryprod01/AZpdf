# Plugin cục bộ của AZpdf

AZpdf chạy hoàn toàn không cần cloud. Plugin là tùy chọn và chỉ được phát hiện từ:

`~/Library/Application Support/AZpdf/Plugins/`

Mỗi plugin cung cấp một tệp manifest JSON. AZpdf chỉ chấp nhận manifest có `runsLocally: true` và `protocolVersion: 1`; ứng dụng không tự tải plugin, không gửi PDF đến Internet và không chạy tác vụ AI ngầm.

Các capability dự kiến: `ocr`, `translate`, `summarize`.

Xem [protocol](../docs/PLUGIN_PROTOCOL.md) trước khi phát triển plugin. Việc thực thi plugin chưa được bật: bản phát hành chỉ mở rộng khi có XPC sandbox cục bộ và yêu cầu cấp quyền rõ ràng theo từng tài liệu.
