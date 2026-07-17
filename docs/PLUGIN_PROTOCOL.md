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

Host còn resolve symlink của manifest và executable trước khi hiển thị plugin; cả hai phải còn nằm trong thư mục `Plugins`. Plugin trỏ ra ngoài qua symlink bị từ chối.

## Grant theo tài liệu

Trước khi XPC host chạy plugin, AZpdf tạo `PluginDocumentGrant` **chỉ trong bộ nhớ** cho một `documentScopeID`, plugin ID và các capability đã yêu cầu. Grant không lưu URL/Bookmark của PDF, không được lưu qua lần mở app và không thể dùng cho PDF/plugin/capability khác. XPC host sau này phải kiểm tra grant này trước khi tạo bản sao chỉ-đọc cục bộ.

## Quy tắc an toàn bắt buộc

- Plugin không được mở socket, gọi HTTP hoặc tự gửi tài liệu/telemetry.
- Host chỉ chạy plugin sau một thao tác rõ ràng của người dùng trên tài liệu đang mở.
- Host sẽ hiển thị capability, executable và phạm vi dữ liệu trước khi cấp quyền.
- Plugin phải hoạt động trên bản sao tạm cục bộ do host cấp; host xóa bản sao sau tác vụ.
- Kết quả phải được trả về cục bộ và chỉ ghi vào PDF khi người dùng xác nhận.

## Trạng thái v1

AZpdf hiện có discovery/validation manifest và không tự chạy executable. Không plugin nào có thể truy cập PDF chỉ bằng cách cài manifest.

Không xem chmod, thư mục tạm hay `runsLocally` là security sandbox; chúng không đủ điều kiện phát hành.

## Thiết kế thực thi v2

AZpdf **không** sẽ chạy executable native tùy ý trong `Application Support` rồi gọi đó là sandbox. Một XPC service chỉ là ranh giới quyền hạn khi chính service được nhúng trong app, ký mã và có entitlement riêng; nó không biến binary cộng đồng cài bên ngoài thành code đáng tin cậy.

Mô hình plugin mặc định của v2 là **Wasm worker local**:

- Host dùng runtime Wasm nhúng, không cấp network, process spawning, quyền đọc filesystem tùy ý hay quyền ghi PDF.
- Mỗi lần chạy có giới hạn bộ nhớ, thời gian và lượng lệnh; mọi input/output là payload có schema và kích thước giới hạn.
- Host cấp dữ liệu đã chọn (trang raster hoặc text layer), không cấp URL PDF, bookmark hay quyền Keychain.
- Kết quả chỉ là dữ liệu (text, boxes, confidence); host xác thực rồi mới cho người dùng xem/áp dụng.
- `PluginDocumentGrant` vẫn là quyền một lần theo document/plugin/capability; hết tác vụ là thu hồi và xóa dữ liệu tạm.

XPC được dùng cho worker do AZpdf phát hành (ví dụ OCR engine nặng), với App Sandbox tối thiểu và code-signing requirement để chỉ AZpdf được kết nối. Native plugin bên thứ ba sẽ không nằm trong phạm vi v1/v2 cho đến khi có mô hình ký, audit và entitlement có thể kiểm chứng.

## Điều kiện phát hành thực thi plugin

- Runtime và mọi XPC service phải được ký lồng theo app trước khi ký bundle ngoài cùng.
- Service từ chối client không thỏa code-signing requirement của AZpdf.
- Không cấp entitlement network cho worker mặc định; capability mới cần review bảo mật và đồng ý rõ ràng của người dùng.
- Có test từ chối manifest, symlink, capability ngoài grant, payload quá cỡ, timeout và kết nối từ client không hợp lệ.
