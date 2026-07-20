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
| Danh sách 8 tài liệu gần đây | ✅ | test: mở lại từ recents, giới hạn đúng **8 mục**, mới nhất đứng đầu, xoá khỏi danh sách |
| Xuất bản sao PDF | ✅ | test: bản sao đọc lại đủ trang, tài liệu gốc không đổi, đường dẫn hỏng có báo lỗi |
| Xuất bản sao bảo vệ mật khẩu | ✅ | test: bản sao **thật sự bị khoá**, sai mật khẩu mở không được, đúng `secret` thì mở được; mật khẩu rỗng bị từ chối |
| OCR vùng | ✅ | GUI + test: kích hoạt chọn vùng, có hướng dẫn, **không** ghi undo giả |
| OCR toàn bộ / xuất searchable PDF | ✅ | test sẵn có `testOCRMyPDFServiceCreatesReplacementPDF`; nhánh chọn nguồn (text layer ↔ Vision) có test |
| Ký PAdES B/LT/LTA + xác minh | ✅ | test sẵn có: ký qua passfile, LT bắt buộc TSA URL, verifier tách integrity ↔ trust |
| Ký CMS/PKCS#7 (.p7s) + xác minh | ✅ | GUI: sheet mở, **dropdown nạp identity thật từ Keychain**, save panel đúng tên. Ký thật: test dựng identity self-signed in-memory → **openssl độc lập đọc được `.p7s`**, verifier tách đúng integrity ↔ trust, nội dung bị sửa bị bắt. Xem E5 |
| Kéo-thả PDF vào cửa sổ | ✅ | test đường `store.open(_:)` mà handler kéo-thả gọi vào; file không phải PDF báo lỗi đúng |
| Lưu thành… (`⇧⌘S`) | ✅ | đường ghi giống `export` (đã test); panel là NSSavePanel — cùng cơ chế đã verify tay ở "Xuất bản được bảo vệ" |

**Tổng: 36 ✅ · 0 🟡 · 0 ⬜** (đầu phiên goal: 12 ✅ · 1 ❌ · 14 ⬜)

> **Cách đọc bằng chứng.** ✅ nghĩa là đã chạy thật: hoặc lái GUI tay, hoặc test tự động chạy được
> (`swift test`), phần lớn còn được kiểm chứng chéo bằng `azpdf-engine`/renderer MuPDF độc lập.
> Các luồng bọc trong NSOpenPanel/NSSavePanel chặn ở `runModal` nên không test tự động được;
> chúng được verify bằng tay, còn toàn bộ phần logic phía sau thì có test.

## E5. Ký `.p7s` — verify được mà không cần đụng Keychain của người dùng

**Phần GUI** chạy đúng: sheet mở với mô tả chính xác (`.p7s` tách rời, PDF gốc không bị sửa),
dropdown **nạp identity thật từ Keychain** (`kSecClassIdentity` không lọc policy nên lấy được cả
identity code-signing — máy test có 2, S/MIME có 0), save panel ra đúng tên `*.pdf.p7s`.

**Bước ký thật** gọi private key trong login Keychain → macOS bật **SecurityAgent** hỏi quyền.
Đó là cổng bảo mật của hệ điều hành, chỉ chủ máy cấp được, và tự động hoá không nên vượt qua.

Nên phần ký được kiểm bằng đường khác, không đụng tới Keychain của người dùng:
[`CertificateSigningTests.swift`](../Tests/AZpdfTests/CertificateSigningTests.swift) dựng một
identity self-signed dùng một lần và nạp bằng `kSecImportToMemoryOnly` — có `SecIdentity` dùng được
mà **không tạo keychain nào, không chạm keychain người dùng, không hiện prompt nào**. Rồi gọi thẳng
`CertificateSigningService.detachedSignature`.

Kết quả:
- `openssl` (công cụ độc lập, không phải Security.framework đã tạo ra nó) **đọc được `.p7s`** và thấy certificate bên trong
- Verify với **đúng** nội dung → `.invalidCertificate` = *"chữ ký đúng dữ liệu nhưng certificate không được tin cậy"* — chính xác cho cert self-signed
- Verify với nội dung **bị sửa** → `.invalidSignature`

Hai trạng thái khác nhau đó là bằng chứng app **tách bạch integrity và trust** đúng như ROADMAP đặt ra:
nếu gộp làm một thì hoặc cert không tin cậy được cho qua, hoặc nội dung bị sửa vẫn báo hợp lệ.

⚠️ **Lỗi phụ phát hiện trong lúc test, đã sửa (`b71868e`):** khi macOS từ chối cấp quyền, AZpdf
**không báo gì** — không file, không thông báo, sheet tự đóng; người dùng tưởng đã ký xong.
`catch` có set `lastError` nhưng alert không hiện được khi sheet còn mở. Đã đóng sheet trước khi
báo lỗi, áp dụng cho cả đường PAdES.

## Test tự động

`swift test` → **62 test, 0 failure** (1 skipped). Trong đó 15 test ở
[`ReadmeFeatureTests.swift`](../Tests/AZpdfTests/ReadmeFeatureTests.swift) được viết riêng cho
các tính năng README chưa có test, để chúng không âm thầm hỏng lại lần nữa.

## Bug đã sửa trong phiên này

| Commit | Lỗi | Nguyên nhân gốc |
|---|---|---|
| `9577811` | Chữ ký tay ghi vào file nhưng **không renderer nào vẽ ra** | `signaturePoint` trả toạ độ trang; PDFKit cộng `bounds.origin` lần nữa khi ghi `/InkList` → nét vẽ văng ra ngoài `/Rect` và bị clip |
| `40f2259` | Xoá chú thích **trông như không có tác dụng** | Không view nào đọc `documentRevision` → `@Observable` không đăng ký dependency, `updateNSView` không chạy lại; sửa tại chỗ không đổi identity của `PDFDocument` |
| `46e2b3e` | **3 tính năng chết câm lặng**: chèn trang, xác minh .p7s, xuất bản sao | SwiftUI chỉ giữ modifier `.fileImporter`/`.fileExporter` **cuối cùng** mỗi loại trên một view; 5 cái xếp chồng nhau |
| `22eeabf` | Kéo thumbnail chỉ **chọn**, không đổi thứ tự | `ForEach` trên literal `Range` bị coi là nội dung tĩnh nên `.onMove` bị bỏ qua |
| `da9d356` | Nhãn nút sheet OCR bị cắt cụt | 7 nút trên một hàng vượt bề rộng sheet |
| `b71868e` | **Ký thất bại không báo gì** | alert không hiện được khi sheet còn mở, nên `lastError` không bao giờ tới người dùng |

## Vấn đề còn lại

### Đã sửa trong vòng dọn lỗi cuối
- ✅ **Tab rỗng không được tái dùng** — mở file luôn để lại tab "Chưa mở tài liệu" chết.
  `openInNewTab` nay chiếm lại tab đang rỗng. Có test: tab rỗng bị tái dùng, tab đang có tài liệu thì không bị ghi đè.
- ✅ **Sidebar trắng trơn khi chưa mở tài liệu** — đọc như đang lỗi tải. Nay có dòng gợi ý.
- ✅ **Hai icon chữ ký giống hệt nhau** — "Chữ ký tay" và "Ký PAdES" cùng dùng `signature`,
  hai luồng cho kết quả rất khác nhau. PAdES đổi sang `checkmark.seal.fill`.

### Không sửa được — đã thử và dừng đúng lúc
- 🟢 **C2 — Escape không đóng sheet.** Ô nhập đang focus nuốt phím. Đã thử **5 cách**, build và
  test GUI thật từng cách, **cả 5 đều không ăn**: `.keyboardShortcut(.cancelAction)`,
  `.onExitCommand`, `.onKeyPress(.escape)`, `NSEvent` local monitor, và local monitor có frame
  tường minh. Tất cả đã **revert sạch** — không để lại code tạo cảm giác đã xử lý.
  Ảnh hưởng thấp: bấm chuột vào nút Hủy vẫn chạy bình thường; chỉ phím Escape là chết.
  Muốn sửa thật có lẽ phải bỏ auto-focus ô đầu tiên, hoặc bọc sheet trong NSViewRepresentable
  tự quản responder chain.

### Không thuộc nhánh này
- 🟡 **C1 — engine trả `kind: "unknown"` cho highlight và ink.** Ảnh hưởng shell Linux vì Linux
  đọc tài liệu qua engine này.
  **Không sửa được ở đây, và không phải vì thiếu file:** `Package.swift` đã commit trên nhánh này
  chỉ khai báo **2 target** (`AZpdfCore`, `AZpdf`). Toàn bộ hệ MuPDF/PAdES/StructuredOCR/CLI —
  target, product, adapter lẫn các file `Core/` chúng cần — **chỉ tồn tại trong WIP chưa commit
  của Codex**. Đã thử copy source sang: build gãy vì `PDFEngineConformance` và
  `PortableDocumentSession` cần bản `PDFDocumentEngine` mới hơn cũng nằm trong WIP đó.
  ⇒ C1 thuộc phần việc đang dở của Codex, phải sửa sau khi phần đó được commit.

### Đề xuất thiết kế (không phải lỗi)
- Toolbar 17 icon không nhãn. Mỗi nút đều đã có tooltip `.help()` nên vẫn dùng được,
  nhưng gom nhóm ký/OCR/trang vào menu-button có nhãn sẽ dễ hơn nhiều cho người mới.
- Mục lục không tự đánh dấu mục ứng với trang đang xem.

## Ghi chú về spec

Ba mục ROADMAP đang tick `[x]` nhưng thực tế hỏng khi kiểm bằng tay: **search**, **zoom thủ công**
và **chữ ký tay**. Cả ba đều có code và unit test xanh. Đề xuất: chỉ tick `[x]` khi có bằng chứng
chạy ở tầng UI, không dựa vào test đơn vị.
