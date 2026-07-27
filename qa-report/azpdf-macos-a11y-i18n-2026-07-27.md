# QA macOS — accessibility đo bằng AX API + i18n en/vi (2026-07-27)

Phiên này làm hai việc: hoàn tất localization, và **đo** accessibility thay vì suy đoán.
Phép đo đính chính một khẳng định đang được dùng làm căn cứ lập kế hoạch.

## A. Đính chính: "17 icon toolbar không nhãn" là SAI

Bản kế hoạch nâng cấp (`.forge/2026-07-23-nang-cap-tieu-chuan-nganh/plan.md`) xếp accessibility vào
nhóm **chặn đường**, ước lượng 1–2 tuần, với bằng chứng là:

> `grep accessibility Views/` = 1 → "17 icon toolbar là 17 nút vô nghĩa với VoiceOver"

**Đếm modifier `accessibility*` là thước đo sai.** SwiftUI tự cấp nhãn từ `Label(text, systemImage:)`
và từ `VStack{Image; Text}` — hai dạng mà toolbar và edit bar của AZpdf vốn đã dùng.

### Cách đo

Dump cây accessibility của app **đang chạy** qua AX API (`AXUIElementCopyAttributeValue`), đọc
`AXDescription` → `AXTitle` → `AXHelp` cho mọi `AXButton`/`AXCheckBox`/`AXPopUpButton`.

| Trạng thái đo | Tổng control | Không nhãn |
|---|---|---|
| Cửa sổ chính, mặc định | 50 | 12 |
| Cửa sổ chính + edit bar + inspector | 47 | 6 |

Truy từng nút không nhãn theo đường dẫn AX và vị trí: **100% là component của AppKit** —
`AXScrollBar/AXButton` (nút cuộn) và `AXCloseButton`/`AXMinimizeButton`/`AXFullScreenButton`
(traffic light của cửa sổ). VoiceOver xử lý chúng theo `AXSubrole`, không cần app tự đặt nhãn.

**Không có control nào do AZpdf viết mà thiếu nhãn.** Toàn bộ 21 nút edit bar đọc ra đúng tên:
Note · Text · Signature · Highlight · Image · Shape · Redact · Rotate · Duplicate · Insert PDF ·
Export Page · Export Protected · OCR Page · OCR Region · OCR All · Sign .p7s · Sign PAdES · Verify.

## B. Nhưng chính phép đo lộ 2 lỗi thật

### B1. Hai nút "Delete" đọc y hệt nhau (a11y — đã sửa)
Nút xóa trang (mục *Current Page*) và nút xóa chú thích (mục *Annotations*) cùng đọc `"Delete"`.
Người dùng VoiceOver đi qua Inspector không phân biệt được hai nút, mà một trong hai **xóa cả trang**.

Sửa: `.accessibilityLabel(L("Delete Page"))` và `L("Delete annotation \(index + 1)")`.
Xác nhận lại bằng AX dump: hai nhãn giờ khác nhau.

### B2. Nút Inspector bị cắt cụt dưới tiếng Anh (i18n/layout — đã sửa)
Cột inspector rộng 250–360 pt. Bốn nút một hàng vốn vừa với nhãn tiếng Việt; nhãn tiếng Anh dài hơn
khoảng 20% nên hiện `"Dupli…"` và `"Export…"`.

Đây đúng là rủi ro đã nêu khi review sub-slice 1 ("tiếng Anh thường dài hơn ~20%, có chuỗi nào vỡ
layout không?") nhưng **chưa ai kiểm** — nó chỉ lộ ra khi chạy app thật ở locale `en`.

Sửa: `Grid` 2 hàng × 2 nút. Verify bằng mắt: cả bốn nhãn hiện đủ chữ.

## C. i18n — trạng thái

| | |
|---|---|
| Hạ tầng | `.lproj/Localizable.strings` + `.stringsdict`, helper `L(_:)` |
| Phủ | 37 file (toàn bộ Views/Stores/Services/Models của target `AZpdf`) |
| Bảng chuỗi | 361 key mỗi bên, parity có test canh |
| Chọn ngôn ngữ | Settings → Theo macOS / English / Tiếng Việt, **áp dụng ngay** không cần khởi động lại |
| Gate CI | `script/audit_i18n_strings.sh`, self-test có sẵn |

**Ghi chú hạ tầng:** `.xcstrings` (String Catalog) **không chạy** dưới `swift build` CLI — SwiftPM
copy thô, runtime bỏ qua. Đường chạy được là `.lproj`, với hai điều kiện: bundle `AZpdf_AZpdf.bundle`
phải được copy vào `Contents/Resources`, và Info.plist phải có `CFBundleAllowMixedLocalizations`.

### Hai điểm mù đã biết của gate (còn nguyên, ghi lại để không ai tưởng gate phủ hết)

1. **Gate chỉ bắt ký tự tiếng Việt có dấu.** Một literal tiếng Anh chưa qua `L()` hoàn toàn trong
   suốt với nó. Đã tìm bằng mắt và sửa 4 chỗ (`Picker("Profile")` ×2, `Picker("Certificate")`,
   `GroupBox("OCR local-first")`) — nhưng không có gì đảm bảo đã hết.
2. **Gate cố ý bỏ qua key nội suy** (key `.strings` là chuỗi format `%lld`, không phải chuỗi nguồn).
   Thiếu bản dịch cho chúng là vô hình với gate và lòi tiếng Anh giữa UI tiếng Việt.
   **Test là lớp bảo vệ duy nhất** — đã ghim `"Delete annotation %lld"` ở cả hai ngôn ngữ.

## D. Kết quả

- **183 test / 7 skip / 0 fail**; `audit_i18n_strings` + `audit_local_first` + `audit_portable_core`
  đều exit 0; self-test của gate i18n pass.
- GUI verify: locale `en` → tab và tiêu đề cửa sổ hiện "No Document Open" (lỗi "Chưa mở tài liệu" lộ
  ở locale `en` đã hết); locale `vi` → sheet kiểm chuẩn PDF đủ tiếng Việt.
- Mutation-check: bỏ bản dịch `vi` của key nội suy → test đỏ; khôi phục → xanh.

## E. Còn lại

Trong nhóm bốn hạng mục "chặn đường" của bản kế hoạch, **chỉ còn hiệu năng file lớn là chưa ai đo**.
Benchmark duy nhất hiện có là ba fixture 1 trang; thumbnail sidebar vẫn render đồng bộ trong view body
(`Views/SidebarView.swift`). Mọi tuyên bố về hiệu năng vẫn là phỏng đoán cho tới khi có số.
