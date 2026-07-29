# AZpdf 1.1.0

**English** | [Tiếng Việt](#tiếng-việt)

Apple silicon (arm64), macOS 14 Sonoma or later.

> GitHub's automatic compare link for this release points at the wrong history: v1.0.0
> was tagged on an old branch, not on `main`. This changelog was written by hand from
> the real delta.

## Printing

- Print the document (`⌘P`) through the system print dialog; annotations are included
  and rotated pages print the right way up.

## Bilingual UI (English/Vietnamese)

- Pick English or Vietnamese in Settings; the interface updates immediately, no relaunch.
- Every screen was swept for hard-coded text, and a CI check now blocks new untranslated
  strings from landing.

## Insert shapes

- Insert rectangles, ovals, lines, arrows, stars, and triangles. Each one is written as a
  standard PDF annotation subtype (Square, Circle, Line, Ink), so other PDF readers render
  it correctly instead of showing an empty box.

## Direct-manipulation annotation editing

- Click an annotation to select it (a dashed frame for text boxes), drag its handles to
  resize it, nudge it with the arrow keys, press Delete to remove it, and change its
  properties in a popover anchored to the object. Previously a selected annotation could
  only be moved.

## Text formatting for text boxes

- Text boxes support font, size, bold/italic, alignment, border, and background controls.

## Preview-style edit bar and toolbar cleanup

- Edit tools moved into a Preview-style reveal bar; the toolbar itself is compact now
  instead of the previous crowded row of icons.
- Edit-bar icon and layout polish.

## Settings redesign

- Settings was reorganized and tidied up around the new language picker.

## Accessibility fixes

- Two Inspector buttons both read as "Delete" to VoiceOver, even though one deletes a
  page and the other deletes an annotation. They now read differently.
- An Inspector button whose label was clipped in English now fits.

## Fixes

- Sheets now close on Escape.
- Page thumbnails can be reordered by dragging them.
- File pickers now open native macOS panels; the SwiftUI ones were sometimes dropped
  without ever appearing on screen.
- A handwritten signature now stays where you drew it instead of drifting out of place.
- Search, zoom, the inspector, and page navigation now have menu items and keyboard
  shortcuts, so they no longer become unreachable when the toolbar runs out of room.
- A PDF opened from Finder now opens in AZpdf instead of leaving you with an empty window.
- Certificate signing now reports the error when macOS denies access to the private key,
  instead of looking like it succeeded.
- Opening a file reuses the empty starting tab instead of leaving a blank one behind.

## Cross-platform groundwork (not part of this macOS release)

- Linux alpha: a Flutter shell talking to the same Swift core over JSON Lines IPC, with
  MuPDF, PAdES, and OCR adapters and a portable `DocumentIR` document model. There is no
  Linux download in this release.
- A 17-case x 2-engine operation-conformance harness now measures which
  `DocumentOperation` cases each engine actually implements. The first run is a
  baseline, not a pass: PDFKit implements 6 of 17, MuPDF 3 of 17, and **no
  operation is implemented by both** — so nothing has been compared for
  equivalent behaviour yet. That gap is the data the cross-platform work needs.

## Install

Unzip in Finder (double-click) and drag `AZpdf.app` to Applications. If you prefer the
command line, use `ditto -x -k AZpdf-macOS.zip .` — plain `unzip` writes AppleDouble
`._` files into the bundle and macOS then reports the app as damaged.

## Verify

SHA-256 (AZpdf-macOS.zip): `bbddd76ae4875e520ad3dcf0711f435f6f700a6775eabd84fc196247eccbfef5`

```
shasum -a 256 AZpdf-macOS.zip
```

---

## Tiếng Việt

[English](#azpdf-110) | **Tiếng Việt**

Apple silicon (arm64), macOS 14 Sonoma trở lên.

> Link compare tự động của GitHub cho bản này trỏ sai lịch sử: tag v1.0.0 nằm trên nhánh
> cũ, không phải trên `main`. Changelog này được viết tay từ phần khác biệt thật.

## In tài liệu

- In tài liệu (`⌘P`) qua hộp thoại in của hệ thống; annotation được in ra và trang xoay
  in đúng chiều.

## Giao diện song ngữ (Anh/Việt)

- Chọn tiếng Anh hoặc tiếng Việt trong Settings; giao diện đổi ngay, không cần khởi động lại.
- Đã quét toàn bộ giao diện để gỡ chuỗi viết cứng, và có gate CI chặn chuỗi mới chưa dịch.

## Chèn hình

- Chèn hình chữ nhật, hình bầu dục, đường kẻ, mũi tên, ngôi sao, tam giác. Mỗi hình được
  ghi thành một subtype PDF chuẩn (Square/Circle/Line/Ink) nên trình đọc khác vẫn vẽ
  đúng, không phải hộp trắng.

## Chỉnh sửa chú thích trực tiếp trên đối tượng

- Nhấp vào chú thích để chọn (khung nét đứt cho hộp chữ), kéo tay cầm để đổi kích thước,
  phím mũi tên để dịch chuyển, Delete để xóa, và sửa thuộc tính trong popover neo vào
  đối tượng. Trước đây chú thích đang chọn chỉ di chuyển được.

## Định dạng chữ cho hộp văn bản

- Hộp văn bản hỗ trợ chỉnh phông chữ, cỡ chữ, đậm/nghiêng, căn lề, khung viền và nền hộp.

## Thanh chỉnh sửa kiểu Preview + dọn lại toolbar

- Các công cụ chỉnh sửa chuyển vào thanh hiện/ẩn kiểu Preview; toolbar chính gọn lại
  thay vì hàng icon chen chúc như trước.
- Đồng bộ icon và bố cục của thanh chỉnh sửa.

## Thiết kế lại Settings

- Trang Settings được sắp xếp lại và hoàn thiện cùng lúc với việc thêm bộ chọn ngôn ngữ.

## Sửa lỗi trợ năng (accessibility)

- Hai nút trong Inspector cùng được VoiceOver đọc là "Delete", trong khi một nút xóa
  trang và nút kia xóa chú thích. Nay hai nhãn đã khác nhau.
- Nút Inspector bị cắt cụt nhãn dưới bản tiếng Anh nay hiện đủ chữ.

## Sửa lỗi

- Sheet đóng được bằng phím Escape.
- Kéo thả để sắp xếp lại thumbnail trang.
- Các hộp thoại chọn file nay dùng native panel của macOS; bản SwiftUI trước đây có lúc
  bị bỏ qua và không hiện ra.
- Nét chữ ký tay nằm đúng chỗ vừa vẽ, không còn bị lệch đi.
- Tìm kiếm, zoom, inspector và điều hướng trang nay có mục menu và phím tắt, nên không
  còn biến mất khi toolbar hết chỗ.
- Mở PDF từ Finder nay mở đúng trong AZpdf thay vì để lại một cửa sổ trống.
- Ký bằng certificate nay báo lỗi khi macOS từ chối quyền truy cập private key, thay vì
  trông như đã ký xong.
- Mở file dùng lại tab trống ban đầu thay vì để lại một tab trắng.

## Nền tảng đa hệ điều hành (chưa thuộc bản macOS này)

- Linux alpha: Flutter shell gọi cùng core Swift qua JSON Lines IPC, có adapter MuPDF,
  PAdES, OCR và mô hình tài liệu portable `DocumentIR`. Bản này chưa có file tải cho Linux.
- Có harness operation-conformance 17 case × 2 engine để **đo** mỗi engine thực
  sự làm được `DocumentOperation` nào. Lần chạy đầu là số nền, không phải chứng
  nhận đạt: PDFKit làm được 6/17, MuPDF 3/17, và **không op nào cả hai cùng làm
  được** — nghĩa là chưa từng có thao tác nào được so hành vi. Chính khoảng
  trống đó là dữ liệu mà phần đa nền tảng cần.

## Cài đặt

Giải nén bằng Finder (nhấp đúp) rồi kéo `AZpdf.app` vào Applications. Nếu dùng dòng lệnh,
hãy chạy `ditto -x -k AZpdf-macOS.zip .` — lệnh `unzip` thường sẽ ghi các file AppleDouble
`._` vào trong bundle và macOS sẽ báo app bị hỏng.

## Kiểm chứng

SHA-256 (AZpdf-macOS.zip): `bbddd76ae4875e520ad3dcf0711f435f6f700a6775eabd84fc196247eccbfef5`

```
shasum -a 256 AZpdf-macOS.zip
```
