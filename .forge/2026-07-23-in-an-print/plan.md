# Plan — Lát cắt 1c: In ấn cho AZpdf (⌘P, panel in hệ thống, qua PDFKit)

## Goal
⌘P (hoặc File → In…) từ một tài liệu đang mở mở print panel hệ thống dạng sheet;
bản in ra đủ trang, có annotation, in được range trang chọn lọc qua panel.
Phần logic dựng NSPrintOperation được test tự động (kể cả một test end-to-end
headless in-ra-file); phần panel/chiều giấy verify bằng GUI + ghi qa-report.

## Bối cảnh khảo sát (sự thật, không đoán)

- **Chưa có đường in nào**: grep `shouldPrint|printOperation|NSPrintOperation|NSPrintInfo`
  toàn repo = 0 kết quả.
- **API thật tên là `PDFDocument.printOperation(for:scalingMode:autoRotate:)`** — plan lớn ghi
  "PDFView.printOperation" là gần đúng nhưng lệch: `PDFView` chỉ có `print(with:autoRotate:)`
  chạy thẳng panel, không trả operation để cấu hình/test. Operation cần cho test nằm trên
  `PDFDocument`.
- **Store không giữ NSView**: `PlacementPDFView` chỉ nhận lệnh qua chuỗi
  `store.readerAction`/`readerActionID` → `updateNSView` → `perform(_:in:)`
  (Views/PDFReaderView.swift:89-92), và chuỗi này gắn với undo/redraw (`sendReaderAction`
  registerUndoStep). In không phải là edit — nhét vào đó là sai chỗ. `DocumentStore` đã giữ
  `document: PDFDocument` (Stores/DocumentStore.swift:22) và các lệnh menu khác đều gọi thẳng
  method store (pattern `save()`/`saveAs()` trong Stores/DocumentStore+FileIO.swift, tự chạy
  NSSavePanel modal).
- **Probe đã chạy thật trên máy này** (swift script CLI, không app bundle, không window):
  1. `PDFAnnotation(bounds:forType:withProperties:nil)` có `shouldPrint == true` mặc định
     (thử cả highlight và ink) → annotation app tạo SẼ in, không cần sửa 5 điểm tạo annotation.
  2. `op.jobTitle` settable; `showsPrintPanel` mặc định true.
  3. **Headless chạy được**: `printInfo.jobDisposition = .save` + `dictionary()[.jobSavingURL]`
     + `showsPrintPanel = false` + `showsProgressPanel = false` → `op.run()` trả true, file PDF
     output đọc lại đúng 2 trang từ fixture `Tests/Fixtures/source/two-page.pdf`. Đây là đường
     test tự động end-to-end không cần panel.
- **Menu**: `App/OpenPaperApp.swift` thay `CommandGroup(replacing: .newItem)` (dòng 29-40 —
  vụ nuốt New Window là lát 2f, KHÔNG sửa ở đây). Vị trí chuẩn cho Print là placement
  `.printItem` riêng — không đụng nhóm nào đang có. ⌘P chưa bị chiếm. Các lệnh khác gate bằng
  `.disabled(workspace.activeStore.document == nil)` — theo y hệt.
- **Fixture sẵn có**: `two-page.pdf` (test tự động), `annotated-highlight-ink.pdf` (GUI verify
  annotation), `script/generate_pdf_fixtures.sh` sinh `rotated.pdf` bằng mutool (GUI verify
  trang xoay). Test load fixture theo pattern `#filePath` (Tests/AZpdfTests/
  EngineOperationMatrixTests.swift:11-14).
- **Chuỗi UI**: app đang 100% tiếng Việt hardcode (i18n là lát 1a, sau lát này) — dùng "In…"
  hardcode, nhất quán.

## Cách tiếp cận

**In từ `DocumentStore` qua `PDFDocument.printOperation(for:scalingMode:autoRotate:)`,
không qua PDFView.** Lý do:

1. Store đã giữ `PDFDocument`; menu command đã gọi thẳng store — không phải chế thêm plumbing
   lấy NSView instance từ SwiftUI (chuỗi readerAction là cho edit, gắn undo).
2. Fidelity không mất gì: in luôn là full page render từ document (không phụ thuộc zoom/scroll
   của view); annotation in-memory — kể cả `EditableImageAnnotation` custom draw — render qua
   chính `PDFPage.draw` nên vẫn ra bản in. `PDFView.print(...)` bên trong cũng chỉ làm đúng
   việc này nhưng không testable.
3. Testable: builder trả `NSPrintOperation` đã cấu hình mà CHƯA run → test kiểm jobTitle/
   printInfo/panel flags; và probe xác nhận chạy headless in-ra-file được → có cả test
   end-to-end thật.

Cấu hình chọn: `scalingMode: .pageScaleDownToFit` (default của Preview), `autoRotate: true`
(xoay bản in theo chiều giấy), `NSPrintInfo()` mới mỗi lần (KHÔNG dùng `NSPrintInfo.shared`
để test set jobDisposition không làm bẩn global state), `jobTitle = store.title`.
Chạy panel: `runModal(for: NSApp.keyWindow, ...)` (sheet chuẩn macOS), fallback `op.run()`
khi không có key window.

**Phương án bị loại**: (a) in qua chuỗi readerAction tới `PlacementPDFView` — thêm plumbing,
dính undo machinery, không testable, không thêm fidelity; (b) tự dựng NSPrintOperation +
NSView render từng trang — PDFKit đã làm sẵn, viết lại là tự rước bug trang xoay/scaling.

## Các bước

- [x] 1. **Store extension.** File mới `Stores/DocumentStore+Printing.swift` (theo pattern
  `DocumentStore+FileIO.swift`, import AppKit + PDFKit):
  - `func makePrintOperation() -> NSPrintOperation?`: `guard let document else { return nil }`;
    gọi `document.printOperation(for: NSPrintInfo(), scalingMode: .pageScaleDownToFit,
    autoRotate: true)`; set `jobTitle = title`; return.
  - `@MainActor func printDocument()`: lấy op từ builder; nếu có `NSApp.keyWindow` thì
    `op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)`, else `op.run()`.
  → verify: `swift build` xanh.

- [x] 2. **Menu ⌘P + Help.** `App/OpenPaperApp.swift`: thêm trong `.commands` (sau block
  `CommandGroup(replacing: .newItem)`, dòng ~40):
  `CommandGroup(replacing: .printItem) { Button("In…") { workspace.activeStore.printDocument() }
  .keyboardShortcut("p", modifiers: .command)
  .disabled(workspace.activeStore.document == nil) }`.
  KHÔNG đụng nhóm `.newItem`. Thêm 1 `GridRow { Text("In tài liệu"); Text("⌘P") }` vào bảng
  phím tắt `Views/HelpView.swift` (cạnh dòng 15-19).
  → verify: build xanh; chạy app → File menu có "In…" đúng vị trí cuối File menu, disabled khi
  chưa mở tài liệu.

- [x] 3. **Tests.** File mới `Tests/AZpdfTests/DocumentPrintingTests.swift` (`@MainActor`,
  XCTest, `@testable import AZpdf` — theo style `DocumentStoreTests.swift`; load fixture
  `two-page.pdf` theo pattern `#filePath` của `EngineOperationMatrixTests.swift:11-14`):
  - `makePrintOperation()` trả nil khi `document == nil`.
  - Với fixture: op non-nil, `jobTitle == store.title`, `showsPrintPanel == true`,
    `printInfo` không phải `NSPrintInfo.shared`.
  - **End-to-end headless** (đường đã probe): set `jobDisposition = .save`,
    `printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = tempURL`,
    `showsPrintPanel = false`, `showsProgressPanel = false` → `XCTAssertTrue(op.run())`;
    `PDFDocument(url: tempURL)?.pageCount == 2`; dọn temp file.
  - **Pin giả định annotation-in-được**: tạo `PDFAnnotation(bounds:forType:.highlight/.ink,
    withProperties: nil)` như app tạo → `XCTAssertTrue($0.shouldPrint)` — điều kiện để "bản in
    có annotation"; OS đổi default thì test đỏ trước khi người dùng phát hiện.
  → verify: `swift test --filter DocumentPrintingTests` → 0 failures.

- [x] 4. **Mutation check** (kỷ luật repo): tạm xóa dòng `jobTitle = title` → test đỏ; tạm đổi
  expected pageCount → test đỏ; khôi phục → xanh. Ghi kết quả mutate-đỏ/khôi-phục-xanh vào
  commit message (như lát 1e đã làm). Chạy full `swift test` → không failure mới so với baseline
  hiện tại.
  → verify: full suite xanh + commit message có log mutation.

- [ ] 5. **GUI verify + qa-report** (những gì test tự động không với tới):
  - Mở `Tests/Fixtures/source/annotated-highlight-ink.pdf` → ⌘P → panel mở dạng **sheet** trên
    cửa sổ tài liệu; trong panel dùng PDF → "Save as PDF" (không cần in giấy): đủ trang,
    highlight + ink hiện trên bản in.
  - Trong panel chọn range 1 trang (vd "From 2 to 2") → bản Save as PDF chỉ có 1 trang đúng
    trang đó.
  - Sinh `rotated.pdf` (`script/generate_pdf_fixtures.sh`), mở → ⌘P → Save as PDF → chữ đúng
    chiều, không bị cắt.
  - Chưa mở tài liệu: menu "In…" disabled, ⌘P không làm gì.
  - Ghi kết quả vào file dated trong `qa-report/` (theo style `azpdf-macos-2026-07-20.md`).
  → verify: qa-report file tồn tại, đủ 4 mục trên với kết quả PASS/FAIL.

## Rủi ro

- **`shouldPrint` mặc định true chỉ mới xác minh trên máy này** (macOS hiện tại; min target là
  macOS 14). Test pin ở bước 3 là lưới an toàn; nếu đỏ trên máy/OS khác, fix là set
  `shouldPrint = true` tại 5 điểm tạo annotation (Views/PDFReaderView.swift:107,125,163,172 +
  Models/ShapeAnnotation.swift:73) — 5 dòng, không đổi kiến trúc.
- **Trang xoay**: `autoRotate: true` là default hợp lý nhưng tương tác giữa /Rotate của trang và
  autoRotate phải kiểm bằng bản in thật (bước 5, rotated.pdf) — không tin preview trong panel.
  Nếu sai chiều: thử `autoRotate: false` rồi so sánh, chọn theo kết quả thật.
- **Test headless trên CI**: probe chạy OK từ CLI trên máy dev có GUI session; CI headless có
  thể thiếu print system. KHÔNG skip trước — chạy thật đã; chỉ khi CI thực sự fail vì môi trường
  thì tách test end-to-end ra và `XCTSkip` có điều kiện (giữ nguyên các test cấu hình).
- **Tài liệu đang khóa mật khẩu**: gate chỉ theo `document == nil` (nhất quán với "Lưu"); doc
  locked in ra rỗng nhưng app đã prompt mật khẩu ngay khi mở nên thực tế khó gặp — chấp nhận,
  không thêm gate riêng.
- **Annotation chưa flatten**: in qua printOperation render annotation lên bản in (đã có đường
  verify bước 5) — KHÔNG flatten file gốc, đúng mong đợi. Flatten-khi-in không nằm trong lát này.

## UI surfaces

None — chỉ dùng panel in hệ thống (NSPrintOperation sheet), không UI tự vẽ.
Bổ sung 2 mục chuẩn hệ: menu item "In…" (⌘P) ở placement `.printItem` File menu,
và 1 dòng phím tắt trong bảng HelpView. Không cần design review.

## Ngoài phạm vi

- Sửa vụ `CommandGroup(replacing: .newItem)` nuốt New Window (lát 2f).
- Flatten annotation khi in; sửa `shouldPrint` tại điểm tạo annotation (chỉ làm nếu test pin đỏ).
- Nút Print trên toolbar/edit bar.
- In qua engine chung/MuPDF, Shell/Linux/Windows.
- i18n chuỗi "In…" (lát 1a sweep sau).
