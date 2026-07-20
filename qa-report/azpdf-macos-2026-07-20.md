# AZpdf — QA UI/UX macOS (2026-07-20)

Test thủ công theo góc nhìn người dùng thật, lái GUI trực tiếp (không phải unit test).

## Môi trường

| Mục | Giá trị |
|---|---|
| Máy | macOS (Darwin 25.5.0, arm64), Swift 6.3.3 |
| Build | `./script/build_and_run.sh --bundle`, `dist/AZpdf.app` (2026-07-20 02:38) |
| Nhánh | `refactor/document-store-split` @ `71287de` |
| Runtime ngoài | mutool 1.28.0 (`/opt/homebrew/bin/mutool`) |

## Bộ PDF mẫu (`Tests/Fixtures/generated/`)

| File | Đặc điểm |
|---|---|
| `basic.pdf` | 1 trang, text thuần |
| `two-column.pdf` | bố cục 2 cột (kiểm tra reading order/OCR) |
| `rotated.pdf` | trang xoay |
| `multipage.pdf` | 3 trang ghép |
| `encrypted.pdf` | AES-256, mật khẩu `secret` |
| `real-world-manual.pdf` | 11 trang thật, có outline/mục lục, 378 KB |

---

## Kết quả tóm tắt

| # | Mức | Vấn đề |
|---|---|---|
| 1 | **CAO** | Tìm kiếm + toàn bộ điều khiển zoom + inspector **không thể truy cập ở mọi kích thước cửa sổ** |
| 2 | **CAO** | Không mở được PDF từ Finder; `open -a` đẻ cửa sổ trùng lặp dùng chung state |
| 3 | TRUNG BÌNH | 17 icon toolbar không nhãn, không nhóm |
| 4 | THẤP | Tab rỗng "Chưa mở tài liệu" không được tái dùng |
| 5 | THẤP | Sidebar chiếm chỗ nhưng trống khi chưa mở tài liệu |

**Hoạt động tốt:** mở file qua `⌘O`/nút, render sắc nét, fit-page, mục lục PDF thật, 11 thumbnail đồng bộ, `⌘[`/`⌘]` điều hướng chuẩn, indicator trang cập nhật đúng, mở tab độc lập không ghi đè, lọc file non-PDF trong Open panel, danh sách Gần đây có nút xóa.

---

## 1. CAO — Search, zoom, inspector không truy cập được

**Hiện tượng.** Toolbar chỉ hiển thị tới `< 3/11 >` rồi nút tràn `»`. Bấm `»` **không mở gì** (thử 2 lần, 2 toạ độ). Kể cả khi phóng **full-screen (bề rộng tối đa)**, search và zoom vẫn không xuất hiện.

**Không có đường thoát nào khác:**
- `⌘F` **không làm gì**. Trong `App/OpenPaperApp.swift` có **25 phím tắt** nhưng **không hề có `⌘F`**, cũng không có phím zoom (`⌘+`/`⌘-`/`⌘0`).
- Menu **Edit**: chỉ Undo/Redo + Cut/Copy/Paste hệ thống — **không có Find**.
- Menu **View**: chỉ Show Tab Bar / Show All Tabs / Enter Full Screen — **không có zoom**.
- Menu **Điều hướng**: chỉ Trang trước / Trang sau.

**Nguyên nhân gốc.** `Views/ContentView.swift:197-223` — `ToolbarItemGroup(placement: .automatic)` chứa, theo thứ tự sau page indicator:
`TextField("Tìm trong PDF")` (w=180) → đếm kết quả + prev/next → zoom out / % / zoom in / Vừa trang → Thuộc tính → Thông tin.
Cộng với 17 nút ở nhóm trước đó là **~29 toolbar item**, vượt bề rộng màn hình nên bị đẩy vào overflow. SwiftUI **không render được `TextField` và các custom view trong overflow menu**, nên menu tràn rỗng ⇒ mất hẳn.

**Ảnh hưởng.** 3 tính năng README quảng cáo trở thành vô dụng trên macOS: *"Tìm kiếm có số kết quả và điều hướng kết quả trước/sau"*, *"Zoom vừa trang mặc định, với điều khiển zoom tay và quay lại vừa trang"*, và Inspector. Chỉ "Thuộc tính" sống sót nhờ `⇧⌘M` trong menu PDF.

**Tái hiện.** Mở PDF bất kỳ → nhìn toolbar → bấm `»` → thử `⌘F`.

**Đề xuất sửa.**
1. Thêm `CommandGroup(replacing: .textEditing)` với "Tìm trong PDF" `⌘F` + "Kết quả trước/sau" `⌘G`/`⇧⌘G`, focus vào ô search.
2. Thêm `CommandMenu("Hiển thị")` cho zoom: `⌘+`, `⌘-`, `⌘0` (Vừa trang) — độc lập hoàn toàn với toolbar.
3. Bỏ `TextField` khỏi toolbar `.automatic`: dùng `.searchable()` hoặc một find-bar riêng dưới toolbar.
4. Giảm tải toolbar: gom nhóm ký/OCR/trang vào menu-button có nhãn thay vì 17 icon phẳng.

---

## 2. CAO — Không mở được PDF từ Finder, `open -a` đẻ cửa sổ trùng lặp

**Hiện tượng.** Khi app **đang chạy**, `open -a AZpdf.app encrypted.pdf` → xuất hiện **cửa sổ thứ hai** (native tab bar hiện 2 window cùng tên "real-world-manual"), nội dung vẫn là tài liệu cũ. Tab bar trong app **không có tab `encrypted`**, **không có prompt mật khẩu**. File bị bỏ qua hoàn toàn.

**Nguyên nhân gốc (xác minh bằng source, không suy đoán):**
- `grep -rn "onOpenURL|openFile|application(_:open|handlesExternalEvents|NSApplicationDelegate" App/ Views/` → **0 kết quả**. App không có bất kỳ code nào nhận file-open event.
- `dist/AZpdf.app/Contents/Info.plist` **không khai báo `CFBundleDocumentTypes`** ⇒ macOS không đăng ký AZpdf là app mở PDF; double-click PDF trong Finder không bao giờ tới được app.
- `App/OpenPaperApp.swift:9` dùng `WindowGroup` với một `DocumentWorkspace` **dùng chung** ⇒ cửa sổ mới render lại cùng state, giải thích đúng hiện tượng nhân đôi.

**Ảnh hưởng.** Với một trình đọc PDF, double-click file trong Finder là lối vào cơ bản nhất. Hiện chỉ mở được bằng: nút/`⌘O`, kéo-thả (có hoạt động, `ContentView.swift:52`), hoặc danh sách Gần đây. Nhiều cửa sổ dùng chung workspace còn gây rối: sửa ở cửa sổ này ảnh hưởng tab của cửa sổ kia.

**Đề xuất sửa.**
1. Khai báo `CFBundleDocumentTypes` (`LSItemContentTypes = public.pdf`, role Editor) trong phần sinh Info.plist của `script/build_and_run.sh`.
2. Xử lý file đến: `.onOpenURL { workspace.open($0) }` hoặc `NSApplicationDelegate.application(_:open:)` → mở thành tab mới trong workspace hiện tại.
3. Cân nhắc `Window` đơn hoặc `handlesExternalEvents` để không sinh cửa sổ trùng chia sẻ state.

---

## 3-5. Vấn đề UX nhỏ hơn

- **(TB)** 17 icon toolbar **không nhãn, không phân cách nhóm**; ý nghĩa chỉ lộ khi hover. Hai icon chữ ký gần giống hệt nhau (certificate vs PAdES) rất dễ nhầm — hai luồng này cho kết quả rất khác nhau.
- **(Thấp)** Mở tài liệu khi đang ở tab rỗng "Chưa mở tài liệu" → tạo tab mới, để lại tab rỗng chết. Nên tái dùng tab rỗng.
- **(Thấp)** Chưa mở tài liệu, sidebar vẫn chiếm ~215px trắng trơn. Nên tự thu lại.
- **(Quan sát)** Mục lục không tự highlight mục ứng với trang đang xem (đang ở trang "Glossary" nhưng mục "Glossary" ở sidebar không được đánh dấu).

---

## Chưa kiểm tra (thiếu thời gian phiên này)

Annotate (highlight/note/text box/chữ ký/ảnh), OCR (`⇧⌘O`/`⇧⌘V`/`⇧⌘A`), redact, ký số/PAdES, kiểm tra PDF/A, xuất trang/xuất bảo vệ, undo/redo sau chỉnh sửa, thao tác trang (xoay/xóa/nhân đôi/đảo thứ tự), luồng mở `encrypted.pdf` bằng `⌘O` (chưa xác nhận prompt mật khẩu vì bug #2 chặn đường Finder).

> Lưu ý: các luồng trên đều có phím tắt trong menu PDF nên **không bị chặn bởi bug #1**, có thể test tiếp bình thường.
