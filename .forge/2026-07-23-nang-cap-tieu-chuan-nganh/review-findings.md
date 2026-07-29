# Review — Lát cắt 1e: Ma trận operation-conformance 17 case × 2 engine

## Verdict
APPROVE WITH FIXES

Tự chạy để kiểm (không tin lời agent trước):
- `./script/audit_portable_core.sh` → `Portable-core audit passed: Core remains Foundation-only.` exit 0
- Trước fix: `swift test` → `Executed 165 tests, with 7 tests skipped and 0 failures` (khớp code-summary)
- Sau fix: `swift test` → `Executed 166 tests, with 7 tests skipped and 0 failures` (+1 = test mới của reviewer)
- MuPDF chạy THẬT (mutool 1.28.0, không skip): `testMuPDFOperationMatrixBaseline passed (0.862s)`
- Mutation check của reviewer trên postcondition mới (duplicate: đổi marker kỳ vọng P1→P2 ở trang 1)
  → RED đúng chỗ (`duplicate → .failed`, "Kỳ vọng trang 1 chứa AZPDF-P2..., text đọc được: AZPDF-P1"),
  revert → GREEN. Postcondition mới load-bearing.

**Số liệu trong bảng KHÔNG đổi sau fix** — PDFKit 6/11/0, MuPDF 3/14/0, zero overlap. Nghĩa là:
bảng cũ không sai, nhưng trước fix vài ô `supported` được trao dựa trên bằng chứng yếu hơn mức
bảng ngụ ý; giờ chúng được chống lưng bằng marker-check thật.

## Auto-applied (MEDIUM/LOW — đã chạy lại full suite sau khi sửa)

1. **MEDIUM — siết postcondition đếm-trang-suông** (`Core/PDFEngineOperationConformance.swift`):
   - `duplicate`: trước chỉ `pageCount == 3` → engine nhân đôi NHẦM trang vẫn `supported` (bias lạc
     quan, đúng như brief đoán). Giờ thêm: trang 1 phải chứa `AZPDF-P1` (bản sao đúng trang, đúng vị
     trí page+1 — khớp hợp đồng de-facto của PDFKit adapter *và* fake engine trong
     `PortableDocumentSessionTests.swift:98`), trang 2 chứa `AZPDF-P2`.
   - `delete`: trước chỉ `pageCount == 1` → xóa nhầm trang vẫn qua. Giờ: trang 0 còn lại phải chứa `AZPDF-P2`.
   - `insertDocument`: trước chỉ `pageCount == 4`. Giờ: trang 2 chứa `AZPDF-P1`, trang 3 chứa `AZPDF-P2`.
   - `insertPages`: thêm check hai trang gốc giạt đúng quanh index 1 (nội dung trang chèn cố tình
     không assert — `DocumentStore+Pages.swift:61` ghi op này cho trang lấy từ file ngoài, nội dung
     không thuộc contract). Nhánh này hôm nay chưa engine nào chạy tới (cả hai `unsupported`).
   - PDFKit pass toàn bộ check siết ngay lần chạy đầu → 6 ô `supported` của PDFKit giờ là số đo thật.

2. **MEDIUM — vá lỗ hổng postcondition-vắng-mặt-rỗng** (`classify` + 2 case):
   Trước: `try? prepare(...)` nuốt lỗi setup. Hệ quả: trên engine no-op nói dối,
   `removeAnnotation` ("id biến mất") và `flattenAnnotations` ("annotations rỗng") ĐÚNG MỘT CÁCH
   RỖNG → được phân loại `supported`. Đây chính là điểm brief #6 cảnh báo: guard chỉ chứng minh
   bắt được nói dối ở `rotate`, các case vắng-mặt thì không. Giờ:
   - `prepare` failure được ghi lại; nếu `apply` sau đó BÁO THÀNH CÔNG mà prepare đã fail → `.failed`
     (claim không kiểm chứng được). `apply` ném `operationNotSupported` vẫn ra `unsupported` như cũ.
   - `removeAnnotation.prepare`: sau upsert, assert annotation THẬT SỰ tồn tại trước khi remove.
   - `flattenAnnotations.prepare`: seed 1 annotation + assert tồn tại → "rỗng sau flatten" hết vacuous
     (coder có flag điểm này trong code-summary nhưng để nguyên theo câu chữ plan; sửa ở đây rẻ và
     không đổi số nào: cả hai engine vẫn `unsupported`, MuPDF vẫn `supported` removeAnnotation).

3. **MEDIUM — ghim biên độ tin của mutation guard**
   (`Tests/AZpdfCoreTests/OperationConformanceLyingEngineTests.swift`): thêm
   `testGuardCoverageBoundaryAcrossAllSeventeenCases` — chạy đủ 17 case trên LyingEngine, assert
   chính xác: **13/17 bị bắt `.failed`**, 4 case round-trip yếu-có-chủ-đích
   (`setFormValue`/`setOutline`/`upsertEmbeddedFile`/`removeEmbeddedFile`) qua được. Trước fix,
   con số này là 11/17 bắt được + 6 lọt (2 lọt ngoài tuyên bố). Giờ "cảm giác an toàn giả" thành
   biên độ được ghim bằng test: case nào đổi bên là test đỏ.

4. **MEDIUM — canary exhaustiveness compile-time** (`PDFEngineOperationConformance.exhaustivenessCanary`):
   comment cũ trong `EngineOperationMatrixTests.swift:43-44` claim sai — `XCTAssertEqual(results.count, 17)`
   KHÔNG ép ma trận cập nhật khi `DocumentOperation` thêm case 18, vì harness tự liệt kê case của nó,
   không đọc từ enum (thêm case mới → report vẫn 17 dòng → test vẫn xanh → ma trận mục ruỗng im lặng).
   Giờ: switch exhaustive không `default` trong harness → thêm case mới là build đỏ cho tới khi ma trận
   phủ nó. Sửa luôn comment sai.

5. **LOW — qa-report cập nhật khớp harness sau fix** (`qa-report/engine-operation-matrix-2026-07.md`):
   đoạn gate nói dối giờ mô tả đúng biên 13/17 + 4 yếu-có-chủ-đích, và nói rõ postcondition dùng
   marker text chứ không đếm trang; ghi chú row `flattenAnnotations` về seed annotation.

## Needs decision (CRITICAL / HIGH)
Không có. Không tìm thấy lỗi làm sai số liệu trong bảng đã giao:
- Nhiễm chéo giữa case (brief #3): KHÔNG có — `classify` load document mới từ bytes gốc cho từng case
  (`PDFEngineOperationConformance.swift:93`); MuPDF mutate `MuPDFDocument.data` nội bộ, `Data` fixture
  là value type nên bytes gốc không bị chạm; PDFKit `PDFDocument(data:)` parse bản riêng.
- Kết luận qa-report (brief #4): cả 3 dòng đều được số đo chống lưng. "PDFKit 5/6 page ops" đếm đúng
  theo bảng (thiếu `insertPages`); dòng 3 tự giới hạn đúng phạm vi (đo đúng/sai, không đo thời gian,
  chỉ về 1d) — không suy diễn quá số đo.
- "18 case" trong plan vs 17 thật: coder đếm trực tiếp, ghim 17 bằng test và khai báo lệch ở cả
  code-summary lẫn qa-report — xử lý đúng, không bịa case 18.

## Test gaps
- **4 case round-trip vẫn yếu theo đúng plan** (`setFormValue`/`setOutline`/`upsertEmbeddedFile`/
  `removeEmbeddedFile`, `ponytail:` trong harness): trên engine nói dối chúng vẫn ra `supported`.
  Hôm nay vô hại (cả hai engine throw trước khi verify chạy) nhưng thành load-bearing NGAY khi 2g
  wire op đầu tiên trong nhóm này — lúc đó bắt buộc thêm fixture có form field/outline/attachment.
  Biên này giờ bị test ghim nên không thể xấu đi im lặng.
- `redact` postcondition chỉ kiểm text layer — engine "redact" bằng cách vẽ đè mà giữ text sẽ bị bắt,
  nhưng engine xóa text mà giữ ảnh chụp text thì không. Đủ cho mức contract hiện tại (app mac redact
  thật nằm ngoài contract); ghi nhận cho 2g nhóm (iii).

## Punts
- **`notApplicable` như status thứ 4 (brief #5): khuyến nghị KHÔNG thêm bây giờ.** Harness engine-agnostic
  không thể phân biệt cấu trúc — chính PDFKit ném đúng `operationNotSupported` cho cả "thiếu code" lẫn
  "fixture không có field khớp" (`PDFKitDocumentEngine.swift:96`); muốn tách phải nhét tri thức
  per-engine vào harness chung. Chỗ mang caveat hiện tại: footnote bảng md + assert message trong test —
  đủ cho người quyết đọc bảng. Lưu ý còn lại: bản Codable của report (nếu ai đó consume bằng máy) không
  mang caveat này — fix đúng là fixture có form field ở 2g, lúc đó ô này tự thành `supported` và hết mơ hồ.
- ~30 dòng dò mutool + parse version trong `MuPDFOperationMatrixTests` trùng pattern
  `MuPDFAnnotationKindTests` (file đó chưa có version gate). Gộp helper chung sẽ đụng file cũ —
  ngoài phạm vi surgical của lát cắt; gộp khi target này có file test thứ ba dùng chung pattern.
- Warning build `found 10 file(s) which are unhandled` là của `Packaging/flatpak/*` — tồn tại từ trước,
  không liên quan diff này, không đụng.
- `installedMutoolVersion` đọc pipe sau `waitUntilExit` — deadlock lý thuyết nếu output vượt buffer;
  `mutool -v` in 1 dòng nên không bao giờ xảy ra. Không sửa.
