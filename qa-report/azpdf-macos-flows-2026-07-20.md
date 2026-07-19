# AZpdf — QA macOS vòng 2: xác minh fix + các luồng còn lại (2026-07-20)

Tiếp theo [azpdf-macos-2026-07-20.md](azpdf-macos-2026-07-20.md). Test thủ công trên GUI thật,
build `fix/toolbar-and-file-open` @ `d85f1b1`.

## A. Xác minh 2 bug đã sửa

| Bug | Trạng thái | Bằng chứng |
|---|---|---|
| #1 Search/zoom/inspector không truy cập được | ✅ **Đã sửa** | `⌘F` mở find bar **tự focus**; gõ "conformance" → **1/8** + highlight trong tài liệu; menu **Hiển thị** đủ `⌘F`, `⌘G`/`⌥⌘G`, `⌘+`/`⌘−`/`⌘0`, `⌘I` với trạng thái bật/xám đúng; "Phóng to" đổi hiển thị trang |
| #2 Không mở PDF từ Finder | ✅ **Đã sửa** | `open -a app file.pdf` → mở thành **tab mới**, **1 cửa sổ**; `encrypted.pdf` → prompt mật khẩu → `secret` → unlock + render |

> Đính chính báo cáo vòng 1: cửa sổ trùng lặp **là bug thật**, không phải nhiễu từ `open -n`.
> Cùng chuỗi sạch (`open` app → `open -a file`): bản chưa sửa cho 2 cửa sổ + nuốt file; bản đã sửa cho 1 cửa sổ + mở đúng.

## B. Các luồng còn lại — kết quả

| Luồng | Phím tắt | Kết quả |
|---|---|---|
| Xoay trang | `⇧⌘R` | ✅ xoay 90°, tiêu đề chuyển "Đã chỉnh sửa" |
| Hoàn tác | `⌘Z` | ✅ trả trang về đúng trạng thái cũ |
| Nhân đôi trang | `⇧⌘D` | ✅ 11 → 12 trang, thumbnail đúng |
| Hộp chữ | `⇧⌘T` | ✅ sheet → nhập → pill "Nhấp vào PDF để đặt" → đặt đúng vị trí nhấp |
| Tô sáng | `⇧⌘H` | ✅ bôi đen chữ → highlight vàng đúng vùng |
| OCR trang | `⇧⌘O` | ✅ dùng **text layer PDF** (không phí Vision), trích xuất đúng, có hàng "Kiểm tra chất lượng" + trạng thái "Sẵn sàng review" |
| Kiểm tra PDF/A | `⇧⌘K` | ✅ veraPDF cục bộ chạy thật → "Không đạt", **20 hạng mục** kèm rule gốc + mục xổ "Dữ liệu thô từ veraPDF" (~20s do JVM khởi động) |
| Thuộc tính tài liệu | `⇧⌘M` | ✅ đọc đúng title sẵn có; ghi Tác giả → **persist vào file** |
| Lưu | `⌘S` | ✅ ghi đè, cờ "Đã chỉnh sửa" tự xoá |

**Xác minh độc lập bằng `azpdf-engine`** (không chỉ tin GUI) trên file đã lưu:
`378,123 → 477,616 bytes`; `info` trả `author: "AZpdf QA 2026"`; `annotations --page 0` trả
`freeText: "Ghi chu kiem thu AZpdf"`. Chỉnh sửa persist thật vào PDF.

## C. Phát hiện mới

### C1. (TRUNG BÌNH — ảnh hưởng Linux) Engine không map được annotation Highlight
`azpdf-engine annotations --page 0` trả về highlight vừa tạo với `kind: "unknown"`, trong khi
free-text trả đúng `kind: "freeText"`. PDFKit (macOS) ghi Highlight hợp lệ nhưng engine nền MuPDF
không nhận diện subtype.

**Vì sao đáng quan tâm:** shell Linux đọc tài liệu **qua chính engine này**. Một PDF được tô sáng
trên macOS nhiều khả năng phân loại/hiển thị sai khi mở trên Linux. Nên thêm test đối chiếu
annotation giữa PDFKit và MuPDF cho mọi subtype mà app tạo ra.

### C2. (THẤP) 2/4 sheet không đóng được bằng Escape
`DocumentPropertiesSheet.swift:20` và `SignatureSheet.swift:18` dùng `Button(..., role: .cancel)`
nhưng **thiếu `.keyboardShortcut(.cancelAction)`**, trong khi `TextAnnotationSheet` và
`PasswordProtectSheet` có đủ. Bấm chuột vào Hủy vẫn được; chỉ Escape là chết. Không nhất quán.

*Sửa:* thêm `.keyboardShortcut(.cancelAction)` vào 2 nút Hủy đó.

### C3. (THẤP) Nhãn nút trong sheet OCR bị cắt cụt
Sheet OCR có 7 nút trên một hàng nên hiện "OCR tran…", "OCR vùn…", "OCR toàn…", "Xuất PDF…".
User không đọc được nút làm gì. *Sửa:* nới rộng sheet, xuống hàng, hoặc gom nhóm OCR vào menu-button.

### C4. (Quan sát) Nhãn trang sau khi nhân đôi
Nhân đôi trang 1 cho hai mục "Trang 1 / 1" và "Trang 2 / 1" — nhãn phụ giữ page label gốc của PDF.
Đúng chuẩn PDF nhưng dễ gây bối rối; cân nhắc phân biệt rõ số thứ tự và page label.

## D. Chưa test
Chữ ký tay (`⇧⌘G`), ký certificate/PAdES + xác minh, redact (`⇧⌘X`), chèn ảnh (`⌥⌘I`),
chèn trang từ PDF khác (`⇧⌘I`), xuất trang (`⇧⌘E`), xuất bản bảo vệ mật khẩu, đảo thứ tự trang
bằng kéo-thả, OCR vùng/toàn tài liệu, xuất searchable PDF.
