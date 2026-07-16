# AZpdf Local Plugin Protocol v1

## Phạm vi

Protocol này dành cho plugin OCR, dịch và tóm tắt **chạy trên máy người dùng**. Nó không phải giao thức cloud.

## Khám phá

AZpdf quét manifest `*.json` tại:

`~/Library/Application Support/AZpdf/Plugins/`

Manifest tối thiểu:

```json
{
  "id": "org.example.azpdf.ocr",
  "name": "OCR local",
  "version": "1.0.0",
  "protocolVersion": 1,
  "capabilities": ["ocr"],
  "executable": "./ocr-local",
  "runsLocally": true
}
```

`runsLocally` bắt buộc là `true`; AZpdf chỉ load `protocolVersion` mà host hỗ trợ.

`id` phải theo dạng reverse-domain (ví dụ `org.example.azpdf.ocr`). `executable` phải là đường dẫn tương đối nằm trong bundle plugin; đường dẫn tuyệt đối và `..` bị từ chối.

## Quy tắc an toàn bắt buộc

- Plugin không được mở socket, gọi HTTP hoặc tự gửi tài liệu/telemetry.
- Host chỉ chạy plugin sau một thao tác rõ ràng của người dùng trên tài liệu đang mở.
- Host sẽ hiển thị capability, executable và phạm vi dữ liệu trước khi cấp quyền.
- Plugin phải hoạt động trên bản sao tạm cục bộ do host cấp; host xóa bản sao sau tác vụ.
- Kết quả phải được trả về cục bộ và chỉ ghi vào PDF khi người dùng xác nhận.

## Trạng thái v1

AZpdf hiện có discovery/validation manifest và không tự chạy executable. Không plugin nào có thể truy cập PDF chỉ bằng cách cài manifest.

Trước khi bật thực thi, host sẽ dùng một XPC service App Sandbox riêng, nhận bản sao tạm chỉ-đọc của tài liệu sau khi người dùng đồng ý. Không xem chmod, thư mục tạm hay `runsLocally` là security sandbox; chỉ boundary do macOS enforce mới đủ điều kiện phát hành.
