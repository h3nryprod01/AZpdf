# AZpdf — Độ phủ theo README (macOS, cập nhật 2026-07-20)

Mục tiêu: mọi tính năng README quảng cáo phải **chạy thật** và **có bằng chứng**, không chỉ "có code + unit test xanh".

Nhánh `fix/toolbar-and-file-open`. Mỗi mục ✅ đều đã lái GUI thật; các thay đổi ghi ra file
còn được kiểm chứng lại bằng `azpdf-engine` hoặc renderer MuPDF độc lập, không chỉ tin màn hình.

## Bảng độ phủ

| Tính năng (README) | Trạng thái | Bằng chứng |
|---|---|---|
| Mở, đọc, điều hướng PDF | ✅ | mở file, `⌘[`/`⌘]`, indicator + thumbnail đồng bộ |
| Tìm kiếm + số kết quả + điều hướng trước/sau | ✅ *(đã sửa)* | `⌘F` → "conformance" → 1/8 + highlight trong trang |
| Tab độc lập, không ghi đè | ✅ | nhiều tab song song |
| Mục lục/bookmark PDF | ✅ | outline thật của tài liệu 11 trang |
| Thumbnail trang | ✅ | đồng bộ với trang hiện tại |
| Zoom vừa trang / zoom tay / quay lại vừa trang | ✅ *(đã sửa)* | menu Hiển thị `⌘+`/`⌘−`/`⌘0` |
| Chọn văn bản | ✅ | bôi đen chạy |
| Tô sáng vùng chọn | ✅ | highlight vàng, render đúng ở MuPDF |
| Hộp văn bản (free-text) | ✅ | đặt đúng vị trí nhấp; engine đọc lại `kind: freeText` |
| **Chữ ký tay → ink annotation** | ✅ *(đã sửa)* | hiện trong app + `/InkList` nằm trong `/Rect` + MuPDF render ra |
| Ghi chú | ✅ | `⇧⌘N` |
| Quản lý & xoá chú thích qua Inspector, undo | ✅ *(đã sửa)* | xoá → biến mất tức thì; `⌘Z` khôi phục |
| Xoay trang | ✅ | xoay 90°, undo trả lại |
| Nhân đôi trang | ✅ | 11 → 12 trang |
| Xoá trang | ✅ | 3 → 2 trang, undo trả lại |
| **Sắp xếp lại trang (kéo-thả)** | ✅ *(đã sửa)* | kéo trang 1 xuống cuối → thứ tự 2, 3, 1 |
| **Chèn trang từ PDF khác, hoàn tác** | ✅ *(đã sửa)* | 3 → 4 trang đúng vị trí; `⌘Z` về 3 |
| Chèn ảnh, kéo di chuyển, đổi kích thước | ✅ | ảnh chèn được, Inspector có mục "Chỉnh sửa ảnh" |
| Xuất trang hiện tại thành PDF riêng | ✅ | file xuất ra đúng **1 trang** |
| Mở PDF bảo vệ mật khẩu | ✅ | prompt → `secret` → unlock → render |
| OCR trang hiện tại (hybrid) | ✅ | dùng text layer, có hàng "Kiểm tra chất lượng" |
| **Redact phá hủy** | ✅ | sau redact, text layer trang **rỗng hoàn toàn** — nội dung gốc mất thật |
| Kiểm tra PDF/A & PDF/UA (veraPDF) | ✅ | "Không đạt", 20 hạng mục + dữ liệu thô |
| Phát hiện form PDF | ✅ | Inspector báo "Trường tương tác: 0" đúng với tài liệu không có form |
| Undo/redo | ✅ | nhiều thao tác |
| Trạng thái chưa lưu (tiêu đề + Inspector) | ✅ | "Đã chỉnh sửa, chưa lưu" ↔ "Đã lưu" |
| Metadata tài liệu | ✅ | ghi Tác giả → persist vào file |
| Lưu đè | ✅ | cờ sửa đổi tự xoá |
| Danh sách 8 tài liệu gần đây | 🟡 | thấy danh sách + nút Xoá; **chưa test mở lại từ đó** |
| Xuất bản sao PDF | 🟡 | vừa chuyển sang NSSavePanel, **chưa verify GUI** |
| Xuất bản sao bảo vệ mật khẩu | ⬜ | |
| OCR vùng / OCR toàn bộ / xuất searchable PDF | ⬜ | |
| Ký CMS/PKCS#7 (.p7s) + xác minh | ⬜ | cần certificate trong Keychain |
| Ký PAdES B/LT/LTA + xác minh | ⬜ | cần PKCS#12 + runtime pyHanko |
| Kéo-thả PDF vào cửa sổ | ⬜ | code có ở `ContentView.swift:58` |
| Lưu thành… (`⇧⌘S`) | ⬜ | |

**Tổng: 28 ✅ · 2 🟡 · 6 ⬜** (trước phiên goal: 12 ✅ · 1 ❌ · 14 ⬜)

## Bug đã sửa trong phiên này

| Commit | Lỗi | Nguyên nhân gốc |
|---|---|---|
| `9577811` | Chữ ký tay ghi vào file nhưng **không renderer nào vẽ ra** | `signaturePoint` trả toạ độ trang; PDFKit cộng `bounds.origin` lần nữa khi ghi `/InkList` → nét vẽ văng ra ngoài `/Rect` và bị clip |
| `40f2259` | Xoá chú thích **trông như không có tác dụng** | Không view nào đọc `documentRevision` → `@Observable` không đăng ký dependency, `updateNSView` không chạy lại; sửa tại chỗ không đổi identity của `PDFDocument` |
| `46e2b3e` | **3 tính năng chết câm lặng**: chèn trang, xác minh .p7s, xuất bản sao | SwiftUI chỉ giữ modifier `.fileImporter`/`.fileExporter` **cuối cùng** mỗi loại trên một view; 5 cái xếp chồng nhau |
| `22eeabf` | Kéo thumbnail chỉ **chọn**, không đổi thứ tự | `ForEach` trên literal `Range` bị coi là nội dung tĩnh nên `.onMove` bị bỏ qua |
| `da9d356` | Nhãn nút sheet OCR bị cắt cụt | 7 nút trên một hàng vượt bề rộng sheet |

## Vấn đề còn lại (chưa sửa)

- 🟡 **C1 — engine map sai annotation**: `freeText` đúng, nhưng highlight và ink đều trả `kind: "unknown"`
  (bounds vẫn chuẩn). Ảnh hưởng shell Linux vì Linux đọc qua engine này.
  **Bị chặn**: `Adapters/` rỗng trên nhánh này do ~40 file chưa từng được commit.
- 🟢 **C2 — Escape không đóng sheet**: ô nhập đang focus nuốt Escape. Đã thử `.cancelAction`,
  `.onExitCommand`, `.onKeyPress(.escape)` — **cả 3 đều hỏng**, đã revert sạch. Click nút Hủy vẫn chạy.
- 🟢 Toolbar 17 icon không nhãn; 2 icon chữ ký gần giống hệt nhau.
- 🟢 Tab rỗng không được tái dùng; sidebar trống chiếm chỗ khi chưa mở tài liệu.

## Ghi chú về spec

Ba mục ROADMAP đang tick `[x]` nhưng thực tế hỏng khi kiểm bằng tay: **search**, **zoom thủ công**
và **chữ ký tay**. Cả ba đều có code và unit test xanh. Đề xuất: chỉ tick `[x]` khi có bằng chứng
chạy ở tầng UI, không dựa vào test đơn vị.
