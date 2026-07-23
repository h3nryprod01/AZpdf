# Ma trận operation-conformance — PDFKit vs MuPDF (2026-07-23)

Số liệu cho quyết định hướng engine (`plan.md` § Chiến lược engine đa nền tảng, lát cắt 1e).
Đo bằng harness `Core/PDFEngineOperationConformance.swift`: mỗi case của `DocumentOperation`
được `apply` trên một document nạp mới từ fixture gốc, rồi đọc lại state thật (`pageCount`,
`pageDescriptor`, `text`, `annotations`, `metadata`) để phân loại — không tin `apply` không
throw là "đã làm đúng".

- Runtime: `mutool version 1.28.0`, macOS Darwin arm64 (`swift-tools-version: 6.0`)
- Fixture: `Tests/Fixtures/source/two-page.pdf` (2 trang, trang 0 chứa `AZPDF-P1`, trang 1 chứa `AZPDF-P2`)
- Tái tạo: `swift test --filter EngineOperationMatrixTests` (PDFKit), `swift test --filter MuPDFOperationMatrixTests` (MuPDF)
- **Sai lệch so với plan**: `plan.md` mô tả `DocumentOperation` có "18 case". Đếm thật trong
  `Core/DocumentOperation.swift` (2026-07-23) ra **17 case**. Bảng dưới đây là 17 dòng, không phải
  18 — số liệu đo được ưu tiên hơn con số trong plan.

## Kết quả (17 case × 2 engine)

| # | Operation | PDFKit | MuPDF | Ghi chú |
|---|---|---|---|---|
| 1 | `rotate` | supported | unsupported | — |
| 2 | `duplicate` | supported | unsupported | — |
| 3 | `delete` | supported | unsupported | — |
| 4 | `movePages` | supported | unsupported | — |
| 5 | `insertPages` | unsupported | unsupported | PDFKit có case này trong contract nhưng `apply` vẫn ném `operationNotSupported` — không nằm trong 7 case PDFKit thật sự implement |
| 6 | `addAnnotation` | unsupported | unsupported | Cả hai engine chỉ có `upsertAnnotation`/`upsertImageAnnotation`, không có `addAnnotation` thô |
| 7 | `redact` | unsupported | unsupported | App mac có redact thật (phá hủy nội dung) nhưng đi thẳng PDFKit trong Views/Stores, ngoài contract này |
| 8 | `insertDocument` | supported | unsupported | — |
| 9 | `setMetadata` | supported | unsupported | — |
| 10 | `upsertAnnotation` | unsupported | **supported** | Test dùng kind `.freeText` — kind duy nhất MuPDF guard cho phép cùng `.note` |
| 11 | `upsertImageAnnotation` | unsupported | **supported** | — |
| 12 | `removeAnnotation` | unsupported | **supported** | Case này cần bước chuẩn bị (upsert trước) mới có gì để remove |
| 13 | `flattenAnnotations` | unsupported | unsupported | Harness seed 1 annotation trước khi flatten để "annotations rỗng sau flatten" không đúng một cách rỗng trên fixture vốn 0 annotation |
| 14 | `setFormValue` | unsupported* | unsupported | *PDFKit ném `operationNotSupported` vì fixture không có form field khớp `fieldID`, không phải vì thiếu code path — xem `PDFKitDocumentEngine.apply` case `.setFormValue`. Đây là 1 trong "7/18" (nay 7/17) case PDFKit code-level hỗ trợ theo `plan.md` |
| 15 | `setOutline` | unsupported | unsupported | Postcondition yếu có chủ đích (round-trip `dataRepresentation`/`load`) — không case nào chạy tới nhánh này hôm nay nên không kiểm chứng được độ chặt |
| 16 | `upsertEmbeddedFile` | unsupported | unsupported | Như trên |
| 17 | `removeEmbeddedFile` | unsupported | unsupported | Như trên |

**Tổng**: PDFKit 6 supported / 11 unsupported / **0 failed**. MuPDF 3 supported / 14 unsupported / **0 failed**.
Không tồn tại một `DocumentOperation` case nào cả hai engine cùng `supported` — xác nhận bằng
số đo câu "portable core mỏng về nội dung" trong `plan.md`.

Gate "0 case `.failed`" (không engine nào nói dối — throw không xảy ra nhưng postcondition sai)
đạt cho cả hai engine trên fixture này. Các postcondition trang dùng marker text
(`AZPDF-P1`/`AZPDF-P2`), không chỉ đếm trang — duplicate/delete/insertDocument nhân đôi/xóa/chèn
NHẦM trang sẽ bị bắt, không chỉ sai số lượng. `Tests/AZpdfCoreTests/OperationConformanceLyingEngineTests.swift`
ghim đúng biên độ tin của guard: chạy đủ 17 case trên engine no-op "nói dối" → **13/17 case bị bắt
`.failed`**; 4 case còn lại (`setFormValue`/`setOutline`/`upsertEmbeddedFile`/`removeEmbeddedFile`)
qua được vì postcondition round-trip yếu CÓ CHỦ ĐÍCH theo plan (ghi `ponytail:` trong harness) —
tức 4 dòng đó trong bảng trên chỉ tin được ở mức "unsupported hôm nay", chưa có postcondition thật.
Mutation check thủ công (làm sai kỳ vọng postcondition trong harness rồi khôi phục) xác nhận thêm
là baseline trong `EngineOperationMatrixTests` thật sự load-bearing — chi tiết trong `code-summary.md`.

## Kết luận cho người quyết

1. **Chuyển nhóm page ops (rotate/duplicate/delete/movePages/insertPages/insertDocument) vào MuPDF
   trước** — PDFKit đã có 5/6 qua contract chung, chỉ MuPDF thiếu cả 6/6; đây đúng là nhóm (i) trong
   `plan.md` § 2g và là nhóm rẻ nhất để đóng khoảng cách 6 vs 0.
2. **Cái đang chặn Linux/Windows đạt parity qua contract chung**: toàn bộ 14 case MuPDF
   `unsupported` — không chỉ page ops mà cả `redact`, `setMetadata`/`setOutline`, `flattenAnnotations`,
   `setFormValue`, embedded file. Annotation (`upsertAnnotation`/`upsertImageAnnotation`/`removeAnnotation`)
   là mảng duy nhất MuPDF đã đứng vững hôm nay.
3. **Chi phí ẩn cần 1d đo tiếp**: mỗi case MuPDF `supported` trong bảng này tốn nhiều lần spawn
   `mutool` (load, apply, mỗi lần đọc lại postcondition) — đúng như code adapter tự ghi chú
   "subprocess-per-call... chưa đủ cho interactive viewer". Ma trận này đo *đúng/sai*, không đo
   *thời gian*; số round-trip giây/thao tác vẫn phải lấy từ 1d trước khi chốt hướng C cho file lớn.
