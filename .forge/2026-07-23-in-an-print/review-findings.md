# Review — Lát cắt 1c: In ấn (⌘P + PDFDocument.printOperation)

## Verdict
APPROVE WITH FIXES

## Auto-applied
- MEDIUM: mutation-guard gap closed — mutating `scalingMode` → `.pageScaleNone`
  VÀ `autoRotate` → `false` trong `Stores/DocumentStore+Printing.swift:18-19`
  sống sót qua cả 4 test (đã tự chạy, 4/4 pass với code mutate). Guard cũ chỉ
  bám jobTitle + pageCount; hai lever fidelity mà plan § Rủi ro gọi đích danh
  (trang xoay in sai chiều) hoàn toàn không được bảo vệ. Fix: probe xác nhận
  PDFKit ghi hai giá trị này vào `printInfo.dictionary()` dưới key
  `PDFPrintScalingMode` (0/1/2) và `PDFPrintAutoRotate` (0/1) → thêm 2 assert
  vào `testMakePrintOperationConfiguresJobTitleAndPanelFlags`
  (`Tests/AZpdfTests/DocumentPrintingTests.swift:38-50`), kèm comment nói rõ
  key là PDFKit-internal và đường lui nếu OS đổi tên key.
  Mutation re-run sau fix: **RED** (2 failures, đúng 2 assert mới); restore →
  4/4 GREEN; full suite 170 pass / 7 skip / 0 fail — khớp baseline.

## Needs decision (CRITICAL / HIGH)
None.

## Checks per task (evidence)

1. **Builder vs runner tách sạch** — PASS. `makePrintOperation()`
   (`Stores/DocumentStore+Printing.swift:14-23`) chỉ dựng + set jobTitle,
   không run/runModal/panel. `printDocument()` (:26-33) mới chạy. Test headless
   tự cầm operation từ builder rồi tự `run()` với panels off — không dựa vào
   side effect ẩn nào của builder.
2. **Headless test in THẬT** — PASS. `DocumentPrintingTests.swift:55-56` không
   chỉ kiểm file tồn tại: mở lại file output bằng `PDFDocument(url:)` và assert
   `pageCount == 2`. File rỗng/hỏng → nil → đỏ. Tự chạy:
   `Executed 4 tests, with 0 failures` (0.199s). Full suite:
   `Executed 170 tests, with 7 tests skipped and 0 failures (0 unexpected)`.
3. **Nil-guard** — PASS, 3 lớp: menu `.disabled(document == nil)`
   (`App/OpenPaperApp.swift:44`), `printDocument()` guard → no-op,
   `makePrintOperation()` guard → nil (có test :21-24). `title` fallback
   "Chưa mở tài liệu" khi fileURL nil (`Stores/DocumentStore.swift:122`) —
   jobTitle không crash trong mọi trường hợp.
4. **CommandGroup không nuốt gì** — PASS. Diff `OpenPaperApp.swift` chỉ +5 dòng,
   nhóm `.printItem` mới đứng riêng sau block `.newItem` (:29-40 nguyên vẹn,
   vụ New Window của 2f không bị đụng). `.printItem` là placement chuẩn File
   menu cho Print; các nhóm khác không thay đổi.
5. **Cấu hình operation** — hợp lý. `NSPrintInfo()` fresh mỗi lần (test pin
   `!== NSPrintInfo.shared`), `scalingMode .pageScaleDownToFit` = default của
   Preview, `autoRotate: true` là lựa chọn plan chọn cho rủi ro trang xoay —
   giờ được pin bằng test (auto-fix trên); verdict CUỐI về chiều bản in thật
   vẫn thuộc GUI step 5 với `rotated.pdf` (đúng như plan ghi, không đòi test
   cái không test được). pageRange không set trong builder là đúng — panel hệ
   thống xử lý range (GUI step 5 mục 2 verify).
6. **Mutation guard** — gap thật, đã chứng minh bằng chạy thật và đã vá
   (mục Auto-applied).

## Test gaps
- (Đã vá) scalingMode/autoRotate — xem Auto-applied.
- `printDocument()` nhánh `NSApp.keyWindow` (runModal vs run) không test tự
  động được trong headless swift test — chấp nhận, đúng phạm vi GUI step 5.
- Plan step 5 (GUI verify + qa-report) chưa làm — đúng thiết kế, ngoài scope
  coder; checklist đầy đủ nằm trong code-summary "Notes for tester".

## Punts
- `Views/HelpView.swift:20` — dòng CÓ SẴN "Chữ ký tay ⇧⌘S" sai: ⇧⌘S thực tế là
  "Lưu thành…" (`OpenPaperApp.swift:36`), chữ ký là ⇧⌘G (:92). Không thuộc diff
  này (diff chỉ thêm dòng ⌘P ở :17) — không sửa, nêu để lát Help/i18n xử lý.
- Assert theo key PDFKit-internal (`PDFPrintScalingMode`/`PDFPrintAutoRotate`)
  có rủi ro brittle nếu OS rename; comment trong test đã ghi đường lui
  (update/drop assert, GUI check vẫn phủ behavior).
- `@MainActor` trên `printDocument()` redundant (class đã @MainActor) nhưng
  khớp style sẵn có của `DocumentStore+FileIO.swift` — giữ nguyên.
