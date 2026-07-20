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

---

# Vòng 3 — sửa C1/C2/C3 + test nhóm ký/redact/export

## E. Kết quả sửa

| | Trạng thái |
|---|---|
| **C3** nhãn nút OCR bị cắt | ✅ **Đã sửa** — tách 2 hàng, mọi nhãn hiện đủ (đã verify trên GUI) |
| **C2** Escape không đóng sheet | ❌ **Không sửa được** — xem E1 |
| **C1** engine map sai annotation | ⛔ **Bị chặn** — xem E2 |

### E1. C2: chẩn đoán ban đầu SAI, và không sửa được bằng SwiftUI
Báo cáo vòng 2 nói nguyên nhân là thiếu `.keyboardShortcut(.cancelAction)` ở 2/4 sheet. **Sai.**
Thử nghiệm bác bỏ: `TextAnnotationSheet` **vốn đã có** `.cancelAction` nhưng Escape **cũng không đóng**.

Đã thử 3 cách, build + test GUI thật cho từng cách, **cả 3 đều không ăn**:
1. `.keyboardShortcut(.cancelAction)` trên nút Hủy
2. `.onExitCommand { }` ở gốc sheet
3. `.onKeyPress(.escape) { .handled }` ở gốc sheet

**Nguyên nhân thật:** `TextField`/`TextEditor` đang focus nuốt trọn Escape, không truyền lên trên.
Ảnh hưởng **cả 4 sheet** có ô nhập, không phải 2. Click nút Hủy vẫn hoạt động bình thường.

Cả 3 thay đổi đã **revert sạch** — không để lại code tạo cảm giác đã xử lý. Muốn sửa thật có lẽ phải
bỏ auto-focus ô đầu tiên, hoặc bọc NSViewRepresentable bắt `cancelOperation:`. Chưa làm.

### E2. C1 bị chặn: nhánh fix thiếu file do repo untracked
`Adapters/` **rỗng hoàn toàn** và `Core/` thiếu 6 file trong worktree `fix/toolbar-and-file-open`,
vì những file đó **chưa từng được commit** (nằm trong ~40 file untracked). Chỗ cần sửa cho C1
(`Adapters/MuPDF`) **không tồn tại trên nhánh này**.

Cũng phải đính chính: "42/42 test pass" ở vòng 2 chỉ là các test **có mặt trong worktree** —
không bao gồm test của MuPDF/PAdES/StructuredOCR.

**Cần bạn quyết** trước khi sửa C1: commit số file untracked vào nhánh, hay sửa ở worktree gốc `t-i`.

### E3. C1 — phạm vi chính xác hơn
Đo lại trên file thật: engine map **đúng** `freeText` (đủ bounds, contents, textStyle), nhưng
**cả highlight lẫn ink (chữ ký) đều trả `kind: "unknown"`**, dù `bounds` vẫn chính xác:

```
kind=freeText  pos=(190,376) size=(320x52)  contents='Ghi chu kiem thu AZpdf'
kind=unknown   pos=(71,441)  size=(453x30)   <- highlight
kind=unknown   pos=(136,290) size=(260x96)   <- chữ ký
```

## F. 🔴 CAO — Chữ ký tay được ghi vào PDF nhưng KHÔNG hiển thị ở bất kỳ renderer nào

**Hiện tượng.** Luồng UI chạy hoàn hảo: `⇧⌘G` → canvas vẽ được → "Chèn chữ ký" bật →
pill đặt vị trí → nhấp lên trang → tiêu đề chuyển "đã chỉnh sửa" → `⌘S` lưu, file tăng 1.218 bytes,
annotation thứ 3 xuất hiện (`id=object-13`, bounds 260×96 tại (136,290)).

**Nhưng chữ ký không hề xuất hiện.** Không thấy trong AZpdf sau khi đặt, cũng không thấy sau khi
lưu và mở lại. Dựng lại trang bằng **renderer MuPDF độc lập** (`azpdf-engine render`): highlight vàng
render đúng, free-text render đúng, **vùng chữ ký trắng trơn hoàn toàn**.

**Kết luận.** Hai renderer độc lập đều không vẽ được ⇒ lỗi ở **tầng dữ liệu**, không phải hiển thị:
ink annotation nhiều khả năng được tạo thiếu đường vẽ hoặc thiếu appearance stream `/AP`.

**Vì sao nghiêm trọng.** Tính năng *có vẻ* thành công ở mọi bước — không báo lỗi, file phình ra,
annotation có thật. Người dùng ký hợp đồng, lưu, gửi đi, và **chữ ký không tồn tại với người nhận**.
Đây là loại hỏng tệ nhất: hỏng im lặng ở tính năng mang tính pháp lý.

*Bước tiếp theo:* dump `/Annots` của `object-13` xem có `/InkList` và `/AP` không, rồi kiểm tra
đường ghi ink trong `PDFReaderView` xử lý `.signature(strokes)`.

## D. Chưa test
Chữ ký tay (`⇧⌘G`), ký certificate/PAdES + xác minh, redact (`⇧⌘X`), chèn ảnh (`⌥⌘I`),
chèn trang từ PDF khác (`⇧⌘I`), xuất trang (`⇧⌘E`), xuất bản bảo vệ mật khẩu, đảo thứ tự trang
bằng kéo-thả, OCR vùng/toàn tài liệu, xuất searchable PDF.
