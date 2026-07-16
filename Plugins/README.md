# Plugin cục bộ của AZpdf

AZpdf chạy hoàn toàn không cần cloud. Plugin là tùy chọn và chỉ được phát hiện từ:

`~/Library/Application Support/AZpdf/Plugins/`

Mỗi plugin cung cấp một tệp manifest JSON. AZpdf chỉ chấp nhận manifest có `runsLocally: true`; ứng dụng không tự tải plugin, không gửi PDF đến Internet và không chạy tác vụ AI ngầm.

Các capability dự kiến: `ocr`, `translate`, `summarize`.

Việc thực thi plugin sẽ được bổ sung sau trên một tiến trình sandbox cục bộ, với yêu cầu cấp quyền rõ ràng cho từng tài liệu.
