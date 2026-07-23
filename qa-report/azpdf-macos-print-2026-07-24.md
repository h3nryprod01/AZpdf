# QA macOS — In ấn (lát cắt 1c) — 2026-07-24

Test GUI thật trên bản release bundle, sau khi thêm `DocumentStore+Printing` + command ⌘P.
Bổ sung cho phần headless đã test tự động trong `DocumentPrintingTests` (cấu hình operation +
in-ra-file kiểm pageCount).

## Phần chỉ verify được bằng GUI (plan step 5)

| Kiểm | Cách | Kết quả |
|---|---|---|
| ⌘P mở panel in hệ thống | Mở `rotated.pdf` → ⌘P | ✅ panel hiện, có Copies / All Pages / Range from…to / Selection / Layout / nút PDF (Save as PDF) |
| Trang xoay in đúng chiều | `rotated.pdf` (landscape xoay) → preview panel | ✅ nội dung "Rotated landscape fixture" hiển thị **đúng chiều, vừa khít trang** — `autoRotate: true` hoạt động |
| Annotation in ra | `annotated-highlight-ink.pdf` → ⌘P → preview | ✅ highlight vàng hiện rõ trong preview → `PDFAnnotation.shouldPrint` (mặc định true) xác nhận end-to-end qua đường in |
| Trang chọn lọc | panel có All Pages / Range from…to / Selection | ✅ đủ 3 lựa chọn của panel hệ thống |
| Nút Print xám khi thiếu máy in | Máy test không có máy in | ✅ "No Printer Selected" → Print disabled (hành vi hệ thống, không phải lỗi app); Save-as-PDF vẫn dùng được |

## Không kiểm được ở đây
- In ra giấy thật (máy không có máy in vật lý). Đường Save-as-PDF của panel hệ thống dùng cùng
  `NSPrintOperation` nên fidelity tương đương; phần sinh PDF đã được `DocumentPrintingTests`
  headless kiểm pageCount.

## Ghi chú
- Command đặt bằng `CommandGroup(replacing: .printItem)` — đúng vị trí File menu chuẩn macOS,
  không đụng nhóm `.newItem` (New Window giữ nguyên).
