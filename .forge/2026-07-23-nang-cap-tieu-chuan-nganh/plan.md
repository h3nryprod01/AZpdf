# Plan — Nâng cấp AZpdf đạt "tiêu chuẩn cao nhất trong ngành" (định nghĩa lại cho đúng sản phẩm)

> Rev 2 (2026-07-23): người quyết override phần "Không làm" — engine macOS, Windows và Linux
> được đưa vào lộ trình thật. Xem `## Chiến lược engine đa nền tảng` và `## Lát cắt đầu tiên để code ngay`.

## Định vị

**Cạnh tranh trực diện với Acrobat là thua — và không cần thắng.** Acrobat/PDF Expert/PDFgear
có hàng trăm engineer-year cho content editing, cloud, AI. AZpdf là dự án AGPL một người làm.
"Tiêu chuẩn cao nhất" cho AZpdf KHÔNG phải là "nhiều tính năng nhất", mà là:

> **Trình PDF đáng tin nhất có thể kiểm chứng được: local-first có CI bảo chứng, chuẩn mực
> pháp lý (PAdES/PDF-A/PDF-UA) mà không app miễn phí nào trên macOS làm được, và chất lượng
> nền tảng (a11y, i18n, hiệu năng) ngang app macOS thương mại.**

AZpdf đang thắng ở đâu (có bằng chứng, đối thủ miễn phí không có):
- **Local-first kiểm chứng bằng CI**: `script/audit_local_first.sh` chặn URLSession/socket, grep
  0 network client trong App/Core (qa-report/README-COVERAGE.md dòng 145-148). Stirling-PDF cũng
  local nhưng là web app self-host — AZpdf là desktop native duy nhất enforce điều này bằng CI.
- **Ký chuẩn eIDAS**: PAdES B/LT/LTA + .p7s tách rời, verifier tách integrity ↔ trust
  (Stores/DocumentStore+Signing.swift, Tests CertificateSigningTests). Preview: không có.
  Okular: chỉ ký cơ bản. Không app macOS miễn phí nào có PAdES-LTA.
- **Validation PDF/A + PDF/UA bằng veraPDF nội bộ** (Services/PDFConformanceService.swift) — kể cả
  Acrobat Standard không có veraPDF; đây là tính năng của Acrobat Pro Preflight ($$$).
- **Redact phá hủy thật** — QA xác nhận text layer rỗng hoàn toàn sau redact (README-COVERAGE.md dòng 33).
- **Kỷ luật QA hiếm có**: mutation-testing bắt buộc, ma trận 36/36 tính năng lái GUI thật, QA
  report ghi cả lỗi của chính mình (chữ ký tay từng hỏng im lặng — STATUS-2026-07-20.md mục 2.2).

AZpdf không đặt cược vào: content editing kiểu Word (sửa chữ có sẵn trong trang), AI chat,
cloud sync, mobile. Đó là sân của Acrobat/PDFgear.

**Nghịch lý phải nói thẳng:** app validate PDF/UA cho tài liệu nhưng UI của chính nó có đúng
**1** accessibility modifier (grep toàn bộ `Views/`: chỉ `OCRSheet.swift:37`), và app "local-first
cho mọi người" nhưng **100% chuỗi UI hardcode tiếng Việt** (0 `NSLocalizedString`, 0 `.lproj`,
0 String Catalog). Hai điều này khóa toàn bộ người dùng ngoài Việt Nam và làm yếu chính thông
điệp chuẩn mực mà AZpdf đang bán. Đây là hai việc phải làm trước mọi tính năng mới.

## Bảng khoảng cách

| # | Tiêu chí | Best-in-class | AZpdf đang ở đâu | Khoảng cách | Bằng chứng |
|---|---|---|---|---|---|
| 1 | Đọc & hiệu năng file lớn | Preview/PDF Expert: mở nghìn trang mượt | PDFKit `.singlePageContinuous`; **chưa từng benchmark quá 1 trang** (benchmark duy nhất: 3 fixture 1 trang); thumbnail sidebar render **đồng bộ trong view body** | **Lớn (vì chưa đo)** | qa-report/mupdf-prototype-benchmark-2026-07-18.md; Views/SidebarView.swift:121; `Tests/Fixtures/generated/` rỗng trong worktree |
| 2 | In ấn | Mọi đối thủ, kể cả Zathura | **Không có đường in nào**: grep `rint` trong Views/App/Stores = 0; không NSPrintOperation, không menu Print | **Nghiêm trọng** | grep 2026-07-23; App/OpenPaperApp.swift thay cả CommandGroup `.newItem` |
| 3 | Chú thích | Okular (đủ bộ markup + popup note), PDF Expert | Có: note, free-text, highlight, ink signature, image stamp, 6 hình. **Thiếu: underline/strikeout/squiggly, reply/popup thread, bút vẽ tự do (ink chỉ dành cho chữ ký)**. Interop tốt — annotation chuẩn PDF, hơn hẳn Skim (format riêng) | Vừa | grep underline/strikeout = 0; Models/ShapeAnnotation.swift; Skim FAQ (sourceforge.net/p/skim-app/wiki/FAQ) |
| 4 | Chỉnh sửa nội dung thật | Acrobat, PDFgear (sửa text như Word, miễn phí) | Không có — chỉ annotation overlay | Nghiêm trọng về feature, **nhưng không đặt cược** (xem Định vị) | pdfgear.com/edit-pdf-text; không có code content-stream editing |
| 5 | UX/chuẩn macOS | PDF Expert (polish), Preview (chuẩn hệ) | Tabs ✓, phím tắt ✓, tooltip ✓. Thiếu: chế độ hiển thị (2 trang/lật trang), night/sepia, multi-window (CommandGroup thay `.newItem` nuốt luôn New Window), toolbar 17 icon không nhãn | Lớn | Views/PDFReaderView.swift:13 (chỉ 1 displayMode); Views/SettingsView.swift (1 toggle duy nhất); README-COVERAGE.md "Đề xuất thiết kế" |
| 6 | Accessibility (UI của app) | Acrobat (đọc tagged PDF + UI accessible); Preview đọc text nhưng bỏ semantic | **1 modifier trong toàn app**; ROADMAP tự nhận `[ ] Accessibility/VoiceOver audit` chưa làm | **Nghiêm trọng** | grep accessibility Views/ = 1 (OCRSheet.swift:37); ROADMAP.md dòng 30 |
| 7 | i18n | Mọi đối thủ 10-30+ ngôn ngữ | **Chỉ tiếng Việt, hardcode** — 0 NSLocalizedString, 0 .lproj; README/docs cũng 100% tiếng Việt | **Nghiêm trọng** | grep NSLocalizedString Views/App/Stores = 0 |
| 8 | Định dạng & liên thông | PDF Expert (→Word/Excel/JPG, compare); Stirling-PDF (50+ tool) | Xuất .txt (OCR), xuất 1 trang PDF, chèn trang từ PDF khác. Thiếu: xuất ảnh/Word, ghép nhiều file một phát, tách theo khoảng, nén, compare 2 bản | Lớn | README.md dòng 22-24; pdfexpert.com/features; docs.stirlingpdf.com |
| 9 | Ký & bảo mật | Acrobat Pro (redact + **Sanitize document**: metadata, script, attachment, hidden layer) | PAdES B/LT/LTA ✓, p7s ✓, redact phá hủy ✓, metadata sửa được ✓. Thiếu: **sanitize toàn tài liệu** (mới xóa nội dung trang, chưa quét metadata/embedded/script khi redact); LT/LTA **chưa test với TSA/OCSP/trust production** | **Nhỏ — đây là điểm mạnh nhất** | ROADMAP.md dòng 28; helpx.adobe.com/acrobat/using/removing-sensitive-content-pdfs.html |
| 10 | Đa nền tảng | Foxit/PDFgear: Win+mac+iOS+Android+web | macOS ✓, Linux alpha (Flutter+MuPDF, đã QA GUI thật), Windows = 0 | Lớn — **người quyết đã chọn đóng khoảng cách này** | ROADMAP.md dòng 9-11 |
| 11 | Sức khỏe OSS | Stirling-PDF: most-starred PDF tool, 25M download | Có: LICENSE/CONTRIBUTING/SECURITY/SBOM/notarized release/CI/no-telemetry-by-design. **Chết ở khả năng tiếp cận: toàn bộ docs tiếng Việt** → cộng đồng toàn cầu không thể đọc, không thể đóng góp | Lớn (sửa rẻ) | README.md; blog.elest.io/self-host-stirling-pdf |
| 12 | Bundle size | Skim ~vài chục MB; Preview 0 | **363 MB** (veraPDF kéo JRE, OCRmyPDF kéo Python+Tesseract+Ghostscript) | Vừa (đánh đổi có chủ đích) | `du -sh dist/AZpdf.app` = 363M |

## Chiến lược engine đa nền tảng

Ba yêu cầu mới (engine macOS, Windows, Linux ra khỏi alpha) thực chất là **một câu hỏi**:
AZpdf chạy trên một engine hay ba? Trả lời nó quyết định mọi thứ còn lại.

### Hiện trạng đã khảo sát (bằng chứng, không đoán)

- **`DocumentOperation` có 18 case** (Core/DocumentOperation.swift) — đây là contract portable.
  Nhưng độ phủ thực tế của hai adapter **rời nhau gần hoàn toàn**:
  - `PDFKitDocumentEngine.apply` (Services/PDFKitDocumentEngine.swift:37-110) hỗ trợ **7/18**:
    rotate, duplicate, delete, movePages, insertDocument, setMetadata, setFormValue. 11 case còn lại
    `throw operationNotSupported` — kể cả upsertAnnotation/redact, những thứ app mac LÀM ĐƯỢC
    nhưng làm **ngoài contract**, thẳng vào PDFKit trong Views/Stores.
  - `MuPDFDocumentEngine.apply` (Adapters/MuPDF/MuPDFDocumentEngine.swift:148-168) hỗ trợ **3/18**:
    upsertAnnotation (chỉ freeText/note), upsertImageAnnotation, removeAnnotation. Không page ops,
    không metadata, không redact.
  - Hệ quả: **không tồn tại một thao tác ghi nào mà cả hai engine cùng làm qua contract chung.**
    "Portable core" hiện là đúng về kiến trúc nhưng mỏng về nội dung.
- **Harness conformance hiện có chỉ kiểm ĐỌC** (Core/PDFEngineConformance.swift: metadata,
  pageDescriptor, text, annotations list, render) — không kiểm một `apply` nào. Và nó chỉ được chạy
  trên PDFKit (Tests/AZpdfTests/PDFKitDocumentEngineTests.swift:86-90); **chưa bao giờ chạy trên MuPDF**
  (grep Conformance trong Tests/AZpdfMuPDFTests = 0).
- **MuPDF adapter là subprocess-per-call** (mỗi pageDescriptor/text/render spawn một tiến trình
  mutool — MuPDFDocumentEngine tự ghi chú "Read-only CLI prototype... production adapter sẽ thay
  process boundary bằng sandboxed worker/C FFI"). Đủ cho batch và shell alpha, **không đủ cho
  interactive viewer** khi cuộn 500 trang.
- **Shell Flutter Linux** nói chuyện với engine qua JSON bridge `azpdf-engine` (13 lệnh đọc +
  upsert/remove annotation — docs/ARCHITECTURE.md). Linux alpha đã có: đọc/render/tab/search/zoom/save,
  annotation text/note/image, undo snapshot, OCR searchable-PDF, PAdES B. Thiếu so với app mac:
  page ops (xoay/xóa/sắp xếp), highlight/shape/ink, redact, form, veraPDF, .p7s.
- **PDFKit cho không trên macOS** (mất nếu bỏ): PDFView interactive (render tile, scroll, selection,
  find highlight), form widget, print operation, encryption, outline — toàn bộ tầng đọc của app mac
  đang đứng trên nó (Views/PDFReaderView.swift).
- **License — điểm dễ chết đã kiểm:** MuPDF là AGPL-3.0, AZpdf là AGPL-3.0-only → **tương thích,
  đã chốt bằng ADR 0001** (docs/adr/0001, Accepted). AGPL của MuPDF chỉ thành vấn đề nếu tương lai
  muốn dual-license/bản thương mại — khi đó phải mua license Artifex hoặc chuyển PDFium (BSD).
  Không phải blocker hôm nay; ghi lại để không ai ngạc nhiên sau này.

### Ba hướng

| Hướng | Được | Mất | Chi phí | Rủi ro chính |
|---|---|---|---|---|
| **A. Hiện trạng mở rộng**: PDFKit macOS, MuPDF Linux/Windows, mỗi bên tự lớn | Không viết lại gì; PDFKit freebies giữ nguyên | Hai đường code ghi file **lệch nhau mãi mãi** (đã lệch: 7/18 vs 3/18, rời nhau); mỗi tính năng làm 2 lần; bug interop chỉ lộ khi người dùng mở chéo | Thấp trước mắt, **cao kép dài hạn** | Trôi hành vi giữa nền tảng không ai đo |
| **B. Thống nhất MuPDF cả ba** (hoặc PDFium) | Một hành vi, một bộ test, một fixture | Vứt toàn bộ tầng đọc PDFKit của app mac (PDFView, form, print, selection) và viết lại bằng FFI + viewer tự dựng — **XL, nhiều tháng**, trong khi subprocess prototype hiện tại còn chưa phải FFI | XL | Đập cái đang chạy tốt để giải bài toán chưa đo được; app mac thụt lùi 1-2 quý |
| **C. Lai (khuyến nghị)**: MuPDF là **document authority** — mọi `DocumentOperation` GHI đi qua engine chung trên cả ba nền tảng; PDFKit chỉ còn là tầng render/tương tác trên macOS | Mỗi op chuyển vào engine là Linux/Windows nhận nó **miễn phí**; hai nền tảng hội tụ dần, không big-bang; đúng hướng kiến trúc repo đã tuyên bố (ARCHITECTURE.md: "đưa dần hành vi sang session chung"; ADR 0001 hệ quả: DocumentOperation bắt buộc qua PDFDocumentEngine) | macOS mỗi op ghi phải round-trip qua mutool (save→apply→reload) — có chi phí; PDFKit đọc lại file MuPDF ghi cần gate fidelity | **Trả dần theo op** (S-M mỗi nhóm op), không có cục XL nào | Round-trip chậm trên file lớn (đo ở 1d); fidelity chéo hai engine (cần pixel-diff gate — ROADMAP dòng 44 vốn đã ghi là việc mở) |

**Khuyến nghị: hướng C**, với điều kiện tiên quyết: **đo trước khi chuyển** — hiện "engine nào
thiếu gì" là phỏng đoán từ đọc code; phải biến thành bảng số liệu chạy được (đó chính là lát cắt
đầu tiên, xem cuối file). PDFium chỉ xem lại nếu benchmark fidelity/perf của MuPDF trượt ngưỡng
(ADR 0001 đã dự phòng đúng: thay engine chỉ tác động adapter) hoặc nếu ràng buộc AGPL đổi.

### Windows và Linux dưới giả định hướng C

- **Linux ra khỏi alpha = beta rồi v1**: shell Flutter + engine đã chạy thật (QA GUI Ubuntu 24.04).
  Việc còn lại theo đúng ROADMAP chưa tick: (1) chạy **cùng fixture + conformance matrix** như macOS,
  (2) page ops/redact qua engine (là chính các op hướng C phải thêm — một công đôi việc),
  (3) Flatpak manifest public reproducible + Flathub submission, portal KDE thật.
- **Windows v1 = tái dùng tối đa**: Flutter shell trong `Shell/azpdf_desktop` vốn được dựng cho
  "Windows/Linux" (ROADMAP dòng 46 đã tick), CI portable core trên Windows đã khai báo (dòng 45).
  Đường đi: Swift for Windows build `azpdf-engine` + bundle mutool Windows + Flutter Windows build
  + installer. **Mức "xong" của v1**: viewer đọc — open/render/thumbnail/tab/search/zoom, mở từ
  Explorer, không cài toolchain. Annotation/OCR/PAdES là v1.5 (engine đã biết làm, còn lại là
  đóng gói runtime — ROADMAP dòng 58). KHÔNG hứa parity macOS ở v1.

## Lộ trình phân tầng

### Tầng 1 — Chặn đường (không có thì không được gọi là "đạt chuẩn")

| Hạng mục | Tại sao đáng làm | Chi phí |
|---|---|---|
| **1a. i18n: String Catalog + bản tiếng Anh + README song ngữ** | Khóa duy nhất lớn nhất của toàn dự án: mọi user/contributor ngoài VN đều bị chặn ở cửa. Càng để lâu càng đắt — mỗi view mới thêm nợ chuỗi hardcode. SwiftPM hỗ trợ `defaultLocalization` + `Localizable.xcstrings` qua `Bundle.module` | **L** (2-3 tuần: ~19 view + Stores + CLI message; sweep một lượt) |
| **1b. Accessibility pass: VoiceOver + bàn phím cho mọi control** | App bán PDF/UA validation mà UI không accessible là tự bắn vào thông điệp. 17 icon toolbar không nhãn = 17 nút "button" vô nghĩa với VoiceOver. Làm CHUNG một sweep với 1a (cùng đụng từng view một lượt — trả một lần công đọc code) | **M** (1-2 tuần nếu gộp sweep với 1a) |
| **1c. In ấn (⌘P, NSPrintOperation qua PDFView)** | Trình đọc PDF không in được là dưới chuẩn Zathura. PDFKit có sẵn `PDFView.printOperation` — chi phí thấp bất thường so với tác động | **S** (1-2 ngày + test in trang chọn lọc) |
| **1d. Benchmark + fix hiệu năng file lớn** | Chưa ai từng mở PDF 500 trang trong AZpdf một cách có đo đạc. Fixture lớn + scanned 200MB, đo open/scroll/search/RAM; fix biết trước: thumbnail đồng bộ ở SidebarView.swift:121 → async. **Nay gánh thêm vai trò:** đo chi phí round-trip mutool của hướng C | **M** (3-5 ngày) |
| **1e. Ma trận operation-conformance hai engine** | Dữ liệu bắt buộc trước mọi quyết định engine: biến "PDFKit 7/18, MuPDF 3/18, rời nhau" từ kết quả đọc code thành harness chạy được + số liệu ghim bằng test. Là bước 1 thật sự của hướng C; mọi op chuyển vào engine sau này đều được đo bằng chính harness này | **S** (2-3 ngày — xem `## Lát cắt đầu tiên để code ngay`) |

### Tầng 2 — Cạnh tranh (ngang bằng đối thủ ở tính năng dùng hằng ngày)

| Hạng mục | Tại sao | Chi phí |
|---|---|---|
| **2a. Text markup đủ bộ: underline, strikeout, squiggly** | PDF spec cơ bản, mọi đối thủ có, AZpdf đã có sẵn hạ tầng highlight — thêm 3 subtype là việc cơ khí | **S** (2-3 ngày, tái dùng đường highlight) |
| **2b. Bút vẽ tự do (ink tool) + eraser** | Ink annotation đã có cho chữ ký (đã fix + test canh); mở nó thành công cụ vẽ là bước ngắn. Đối tượng học thuật (đối thủ: Xournal++, Skim) cần nó | **M** (1 tuần) |
| **2c. Chế độ hiển thị: 2 trang, lật trang đơn, night mode** | PDFKit có sẵn `displayMode`/`displaysAsBook`; night mode = filter. Chuẩn reader từ thời Preview | **S-M** (3-5 ngày) |
| **2d. Ghép/tách/nén hoàn chỉnh**: ghép nhiều file một thao tác, tách theo khoảng trang, nén ảnh | Đã có "chèn trang từ PDF khác" và "xuất trang hiện tại" — hoàn thiện nốt là đạt parity Stirling cơ bản trên desktop | **M** (1 tuần) |
| **2e. Xuất trang → PNG/JPEG, xuất text toàn tài liệu** | Liên thông tối thiểu; mutool đã bundle sẵn (`mutool draw`) — đường ống có rồi | **S** (2-3 ngày) |
| **2f. Multi-window + khôi phục New Window** | CommandGroup thay `.newItem` hiện nuốt New Window của macOS; sửa nhỏ, đúng chuẩn hệ | **S** (1 ngày) |
| **2g. Engine hội tụ theo hướng C** — chuyển dần các nhóm op ghi của macOS vào contract chung, mỗi nhóm chỉ chuyển khi 1e đo được MuPDF đã ngang: (i) page ops, (ii) annotation đủ loại, (iii) redact, (iv) metadata/outline | Mỗi nhóm op chuyển xong = Linux/Windows nhận miễn phí; đây là cách duy nhất "ba nền tảng" không thành ba codebase | **L rải kỳ** (S-M mỗi nhóm; đan xen giữa các đợt tính năng, không làm một cục) |
| **2h. Linux beta → v1**: cùng fixture/conformance matrix với macOS, page ops + redact trên shell, Flathub manifest public + portal KDE | Ra khỏi alpha theo yêu cầu; ăn trực tiếp thành quả 2g | **L** (3-4 tuần rải, phần lớn là QA + đóng gói reproducible) |
| **2i. Windows v1 (viewer đọc)**: Swift for Windows build `azpdf-engine`, bundle mutool Win, Flutter Windows shell, installer + `qa_windows_smoke.ps1` pass | Yêu cầu người quyết; đường rẻ nhất là tái dùng shell Flutter + engine sẵn có, không dựng WinUI riêng | **L** (3-5 tuần; rủi ro toolchain xem Rủi ro) |

### Tầng 3 — Khác biệt (local-first + mở làm được, kẻ khác không)

| Hạng mục | Tại sao | Chi phí |
|---|---|---|
| **3a. "Chuyển thành PDF/A" một nút** | OCRmyPDF **đã bundle sẵn** và mặc định xuất PDF/A (`--output-type pdfa`); nối nút UI → chạy → verify lại bằng veraPDF đã bundle → báo cáo đạt/không đạt. Vòng lặp convert-rồi-tự-validate này **Acrobat Standard không có**, và không app miễn phí nào trên macOS có | **S-M** (3-5 ngày — hai runtime đều đã đóng gói) |
| **3b. Sanitize document** (metadata, embedded file, script, hidden text) trước khi chia sẻ | Nối dài redact phá hủy đang có thành câu chuyện trọn vẹn "chia sẻ an toàn". Đúng brand quyền riêng tư; checklist rõ (mục Acrobat sanitize làm chuẩn đối chiếu) | **M** (1 tuần, mutool + rewrite metadata đã có đường qua engine) |
| **3c. Hoàn tất PAdES LT/LTA production**: test với TSA/OCSP/CRL/trust store thật | ROADMAP dòng 28 tự nhận chưa xong. Xong nó = app miễn phí duy nhất trên macOS ký LTA tin được — điểm bán hàng số 1 cho user pháp lý/eIDAS ở EU (sau khi có tiếng Anh — phụ thuộc 1a) | **M** (1 tuần, chủ yếu kiểm thử + tài liệu hóa giới hạn) |
| **3d. Ship `azpdf-engine` như CLI được hỗ trợ chính thức** | Binary đã tồn tại, 13 lệnh đã test. Viết docs + cài qua Homebrew = "Stirling-PDF không cần server" cho dân terminal; nam châm hút contributor kỹ thuật | **S** (docs + tap; 2-3 ngày) |
| **3e. Windows v1.5**: annotation + OCR + PAdES runtime trên Windows (ROADMAP dòng 58) | Sau khi 2i chứng minh nền; engine đã biết làm, còn lại là build/audit runtime portable trên Windows | **M-L** (2-3 tuần) |
| **3f. (Moonshot — chỉ sau khi Tầng 1-2 xong) Trợ lý PDF/UA remediation**: DocumentIR → alt-text, reading order → tagged PDF | Hạ tầng IR đã có (Core/DocumentIR.swift: reading order, figure/alt text, table). Tool sửa-cho-accessible ngoài Acrobat Pro gần như không tồn tại; các cơ quan công quyền (bị ràng EU Accessibility Act) đang thiếu tool. Khác biệt thật sự, nhưng đắt | **XL** (nhiều tháng — ghi vào tầm nhìn, KHÔNG cam kết lịch) |

## Thứ tự thực thi

Sắp theo đòn bẩy/chi phí. Hai nguyên tắc: **sweep i18n+a11y đi trước mọi tính năng UI mới**
(mỗi tính năng thêm trước sweep là thêm nợ), và **không chuyển op nào vào engine trước khi
harness 1e đo được nó** (không quyết engine bằng phỏng đoán).

1. **1e Ma trận operation-conformance** — làm NGAY (lát cắt đầu tiên, xem cuối file). Không đụng UI,
   chạy song song với mọi thứ; là dữ liệu đầu vào cho toàn bộ nhánh engine. *Chặn:* 2g, 2h, 2i.
2. **1c In ấn** (S, độc lập, xóa ngay điểm "dưới chuẩn Zathura").
3. **1a + 1b gộp một sweep** (i18n + accessibility, đụng từng view đúng một lần). *Chặn:* 2a-2f, 3a-3b.
4. **1d Benchmark hiệu năng** (song song với 3 — không đụng view code trừ SidebarView; thêm mục đo
   round-trip mutool phục vụ quyết định hướng C).
5. **2g nhóm (i) page ops vào engine** — nhóm dễ nhất, PDFKit đã làm qua contract, chỉ MuPDF thiếu;
   xong nhóm này là Linux có page ops → khởi động 2h song song.
6. **2a text markup + 2c display modes + 2f multi-window** (đợt "reader parity", sau sweep).
7. **2h Linux beta** (fixture chung + Flathub) — ăn output của 2g theo từng nhóm op.
8. **2i Windows v1 viewer** — bắt đầu sau khi 2h chứng minh đường fixture chung chạy; toolchain
   spike (Swift for Windows build azpdf-engine) có thể làm sớm hơn như một probe S để lộ rủi ro.
9. **3a PDF/A convert + 3b sanitize** (đợt "compliance", dựa trên runtime đã bundle).
10. **3c PAdES production + 3d CLI docs** (đợt "trust" — ra sau khi app có tiếng Anh).
11. **2b ink tool, 2d ghép/tách/nén, 2e xuất ảnh** → rồi **3e Windows v1.5**, đánh giá lại **3f**.

**Vẫn không làm** (phạm vi người quyết chưa override): content editing chữ có sẵn trong trang;
AI/chat; cloud; mobile.

## Rủi ro & đánh đổi

- **"Tiêu chuẩn cao nhất trong ngành" theo nghĩa đen là mục tiêu sai** cho dự án AGPL một người.
  Plan này định nghĩa lại thành "cao nhất trong lát cắt trusted/local-first/chuẩn mực". Ba mảng
  platform/engine mới cộng thêm ước lượng **~3-4 tháng người** vào lộ trình — đánh đổi trực tiếp
  với tốc độ ra tính năng Tầng 2/3 trên macOS. Người quyết đã chọn; plan xếp để chi phí đó trả
  dần (hướng C) thay vì trả một cục (hướng B).
- **Swift for Windows là đường ít người đi**: Foundation trên Windows có lỗ hổng hành vi
  (Process/path/encoding), CI Windows mới ở mức "khai báo cho portable core" (ROADMAP dòng 45),
  QA kit từng dừng ở "THIẾU git + swift" trong VM (README-COVERAGE). Giảm rủi ro: chạy **toolchain
  spike một tuần** (build azpdf-engine + chạy `health`/`render` trên Windows thật) TRƯỚC khi cam kết
  lịch 2i; nếu spike trượt, phương án lùi là viết engine bridge Windows bằng C/C++ mỏng quanh mutool
  (JSON contract giữ nguyên nên shell không đổi).
- **Subprocess-per-call là trần hiệu năng đã biết** của MuPDF adapter (tự ghi chú trong code).
  Alpha Linux chịu được; viewer Windows và hướng C trên file lớn thì chưa chắc. 1d phải đo con số
  này; upgrade path là C FFI/worker thường trú — **L**, chỉ làm khi số liệu bắt buộc.
- **Hướng C round-trip fidelity**: file MuPDF ghi phải được PDFKit đọc lại đúng (và ngược lại).
  Gate: mở rộng pixel-diff + round-trip theo ROADMAP dòng 44 trước khi chuyển nhóm op nào có render
  hệ quả (redact, flatten). Không có gate này thì hướng C là đổi bug lấy bug.
- **i18n sweep đụng ~19 view + Stores** — diff to, dễ regress UI. Giảm rủi ro: sweep thuần cơ khí
  (thay literal bằng key, không sửa layout), chạy lại toàn bộ 161 test + lái GUI theo ma trận
  README-COVERAGE có sẵn. Tiếng Anh dịch một lần bởi người, không máy dịch mù.
- **Hiệu năng có thể... đã ổn** (PDFKit lo phần nặng). Khi đó 1d "chỉ" đẻ ra bằng chứng + harness —
  vẫn đáng, vì hiện tại mọi tuyên bố hiệu năng đều là đoán.
- **In ấn qua PDFView.printOperation có góc chết** (annotation chưa flatten, trang xoay). Cần test
  in thật, không tin preview.
- **Sanitize là tính năng bảo mật** — hứa "sạch" mà sót là tệ hơn không hứa. Phải kiểm bằng
  checklist đối chiếu (mutool show + veraPDF + tool thứ ba độc lập), theo đúng kỷ luật
  mutation-test của repo: chứng minh detector bắt được file bẩn trước khi tin nó.
- **PAdES LTA production cần TSA thật** — phát sinh phụ thuộc dịch vụ ngoài khi test; tài liệu hóa
  rõ. Không tuyên bố LTV nếu chưa verify bằng Adobe validator + trust store thật.
- **MuPDF AGPL**: tương thích với AZpdf AGPL-3.0-only (ADR 0001, đã chốt). Điểm chết tiềm ẩn duy
  nhất: nếu tương lai muốn dual-license/bản thương mại thì cần license Artifex hoặc chuyển PDFium
  (BSD) — ADR 0001 đã thiết kế để việc đổi chỉ chạm adapter. Ghi rõ để đi vào với mắt mở.
- **363MB bundle**: tách runtime thành optional download thì nhẹ hơn nhưng vỡ "chạy ngay không cần
  mạng". Đề xuất: giữ nguyên, ghi rõ lý do trong docs — đánh đổi có chủ đích. Windows/Linux bundle
  sẽ cùng cỡ; installer phải nói trước dung lượng.
- **Chỗ ý kiến này có thể sai**: (1) khuyến nghị hướng C dựa trên đọc code + chưa có số đo round-trip
  — nếu 1d/1e cho số xấu (round-trip > 1s trên file thường), phải xem lại mức độ "authority" của
  MuPDF trên macOS; (2) mức cầu thực về PDF/UA remediation (3f) chưa kiểm chứng bằng người dùng thật;
  (3) ước lượng Windows dựa trên giả định Flutter shell tái dùng gần nguyên vẹn — spike sẽ xác nhận.

## Đo bằng gì

**Tầng 1 (đạt/không đạt):**
- i18n: chạy app với locale `en` → **0 chuỗi tiếng Việt xuất hiện trên UI**; CI thêm gate grep chặn
  string literal tiếng Việt mới trong Views/; README.md có bản tiếng Anh đầy đủ.
- A11y: bật VoiceOver, đi hết toolbar + 8 sheet + sidebar + inspector **chỉ bằng bàn phím** —
  mọi control đọc ra nhãn có nghĩa (không còn "button"); checklist per-view lưu trong qa-report.
- In: ⌘P từ tài liệu 11 trang fixture → bản in ra đủ trang, có annotation, trang xoay in đúng chiều.
- Hiệu năng (đo trên máy release chuẩn, ghi vào qa-report như benchmark 2026-07-18 đã làm):
  PDF 500 trang text mở **< 2s** tới trang đầu tương tác được; PDF scan 200MB mở **< 4s**;
  cuộn sidebar thumbnail không giật (main thread không block > 100ms); search toàn văn 500 trang
  **< 3s**; RAM sau mở + cuộn hết < **1.5GB**. Thêm: round-trip save→mutool apply→reload trên
  PDF 500 trang **< 1s** (số quyết định nhịp hướng C).
- Engine matrix (1e): tồn tại harness đo `apply` cho **đủ 18 case** trên cả hai engine; baseline
  hiện trạng ghim bằng test (PDFKit ⊇ 6 op được chỉ định, MuPDF ⊇ 3 op); **0 case `.failed`**
  (engine nói dối — báo thành công mà postcondition sai — phải bị bắt); bảng kết quả nằm trong qa-report.

**Tầng 2:** underline/strikeout/squiggly tạo trong AZpdf → mở bằng Preview và Acrobat Reader hiển
thị đúng loại; 2 trang/night mode bật tắt được và persist; ghép 3 PDF một thao tác, tách trang 5-10
thành file mới, cả hai undo được; xuất trang → PNG mở được.
- Engine hội tụ (2g): sau mỗi nhóm op, số case `.supported` của MuPDF trong ma trận 1e **tăng và
  được ghim bằng test mới**; op đã chuyển thì DocumentStore macOS không còn gọi PDFKit trực tiếp
  cho op đó (grep được).
- Linux v1 (2h): chạy **cùng fixture + cùng ma trận 1e** như macOS trong CI; page ops + redact lái
  được trên GUI shell (QA report như azpdf-linux-shell-gui-2026-07-21.md); Flathub manifest public
  build reproducible.
- Windows v1 (2i): trên máy Windows sạch không toolchain: cài từ installer → mở PDF từ Explorer,
  render/thumbnail/tab/search/zoom chạy; `qa_windows_smoke.ps1` PASS toàn bộ mục viewer; ma trận 1e
  chạy được trên Windows CI cho phần đọc.

**Tầng 3:** file scan thường → "Chuyển PDF/A" → veraPDF nội bộ báo **PASSED profile PDF/A-2b**
(không tự tuyên bố — dùng đúng nguyên tắc hiện có "hiển thị báo cáo gốc"); sanitize file có
metadata + attachment + hidden text → tool độc lập thứ ba xác nhận sạch theo checklist Acrobat;
chữ ký LTA verify hợp lệ bằng Adobe Acrobat validator với trust store thật; `brew install azpdf-engine`
chạy được `health` + `render` trên máy sạch; Windows v1.5: OCR + annotation + PAdES B smoke pass
trên máy Windows sạch.

**Sức khỏe OSS (đo sau 3-6 tháng kể từ khi có tiếng Anh):** ít nhất 1 contributor ngoài không phải
tác giả gửi PR được merge; issue đầu tiên bằng tiếng Anh được trả lời < 1 tuần.

## UI surfaces

None — no UI in this task.

## Lát cắt đầu tiên để code ngay

**1e — Ma trận operation-conformance hai engine.** Nhỏ, một lần xong, đứng một mình có giá trị
(kể cả nếu sau này bỏ hướng C thì bảng số liệu này vẫn là căn cứ), verify hoàn toàn bằng test,
và là bước 1 thật sự của lộ trình engine. Không đụng UI. Ước lượng: 2-3 ngày.

**Nguyên tắc chung cho coder:** tái dùng pattern có sẵn — cách dò mutool + `XCTSkip` lấy từ
`Tests/AZpdfMuPDFTests/MuPDFAnnotationKindTests.swift`; kiểu report Codable lấy theo
`Core/PDFEngineConformance.swift`. `Document` trong engine protocol là `AnyObject`
(Core/PDFDocumentEngine.swift:15) nên `apply` mutate tại chỗ — mỗi case phải chạy trên document
**load mới từ bytes gốc** để các op không nhiễm nhau. Tuân thủ kỷ luật mutation-test của repo.

- [x] 1. **Fixture 2 trang.** Tạo `Tests/Fixtures/source/two-page.pdf`: 2 trang, trang 1 chứa chuỗi
  marker `AZPDF-P1`, trang 2 chứa `AZPDF-P2` (tạo một lần bằng `mutool create` hoặc script nhỏ, commit
  bytes — không sinh lúc chạy test). Cần vì fixture hiện có `annotated-highlight-ink.pdf` không đủ
  cho case `delete` (PDFKit guard `pageCount > 1`) và `movePages`.
  → verify: test tạm (hoặc bước 3) load được bằng cả hai engine, `pageCount == 2`, `text(ofPage:0)`
  chứa `AZPDF-P1`.
- [x] 2. **Harness trong Core.** File mới `Core/PDFEngineOperationConformance.swift` (Foundation-only —
  phải qua `script/audit_portable_core.sh`): hàm generic trên `PDFDocumentReadingEngine` nhận
  `data: Data` (fixture 2 trang), `auxiliaryPDF: Data` (dùng lại chính fixture đó cho `insertDocument`)
  và `imagePNG: Data` (PNG 1×1 hardcode bytes). Với **từng case trong đủ 18 case** của
  `DocumentOperation`: load document mới → `apply` → phân loại vào report Codable:
  `supported` (không throw **và** postcondition đọc-lại đúng), `unsupported` (throw
  `operationNotSupported`), `failed` (throw khác, hoặc **không throw nhưng postcondition sai**).
  Postcondition tối thiểu mỗi case: rotate → `pageDescriptor(0).rotation` đổi 90; duplicate/insertPages
  /insertDocument → `pageCount` tăng đúng; delete → giảm 1; movePages → `text(ofPage:0)` đổi từ
  `AZPDF-P1` sang `AZPDF-P2`; addAnnotation/upsertAnnotation/upsertImageAnnotation → `annotations(onPage:)`
  chứa annotation mới/đúng id; removeAnnotation → upsert trước rồi remove, id biến mất; redact([0]) →
  `text(ofPage:0)` không còn `AZPDF-P1`; setMetadata → `metadata.title` đọc lại đúng;
  flattenAnnotations → `annotations(onPage:0)` rỗng sau flatten; setFormValue/setOutline/
  upsertEmbeddedFile/removeEmbeddedFile → postcondition yếu có chủ đích: không throw + `dataRepresentation`
  load lại được (ghi chú `// ponytail:` trong code — nâng lên postcondition thật khi op này được chuyển
  vào engine ở 2g).
  → verify: `swift build --target AZpdfCore` xanh; `script/audit_portable_core.sh` exit 0.
- [x] 3. **Ghim baseline PDFKit.** File mới `Tests/AZpdfTests/EngineOperationMatrixTests.swift`:
  chạy harness trên `PDFKitDocumentEngine` với fixture bước 1. Assert: report có **đủ 18 case**;
  tập `supported` == {rotate, duplicate, delete, movePages, insertDocument, setMetadata} (setFormValue
  ra `unsupported` vì fixture không có form — assert kèm detail nói rõ); **không case nào `failed`**.
  → verify: `swift test --filter EngineOperationMatrixTests` → 0 failures.
- [x] 4. **Ghim baseline MuPDF.** File mới `Tests/AZpdfMuPDFTests/MuPDFOperationMatrixTests.swift`:
  dò mutool thật (pattern MuPDFAnnotationKindTests, `XCTSkip` nếu thiếu hoặc < 1.24), chạy cùng harness
  trên `MuPDFDocumentEngine`. Assert: `supported` ⊇ {upsertAnnotation(freeText), upsertImageAnnotation,
  removeAnnotation}; mọi case còn lại `unsupported`; **không case nào `failed`**.
  → verify: `swift test --filter MuPDFOperationMatrixTests` → pass (hoặc skipped khi không có mutool;
  không được failure).
- [x] 5. **Mutation check — chứng minh harness bắt engine nói dối.** File mới
  `Tests/AZpdfCoreTests/OperationConformanceLyingEngineTests.swift`: stub engine (in-memory, không cần
  PDF thật) mà `apply` return thành công nhưng không đổi gì → harness **phải** trả `failed` cho `rotate`
  (postcondition bắt được). Kèm mutation check thủ công theo kỷ luật repo: tạm làm sai một postcondition
  trong harness (vd expected rotation) → bước 3 phải ĐỎ; khôi phục → xanh; ghi kết quả vào commit message.
  → verify: `swift test --filter OperationConformanceLyingEngineTests` → 0 failures; log mutation
  fail-khi-mutate/pass-khi-khôi-phục.
- [x] 6. **Bảng số liệu cho người quyết.** Tạo `qa-report/engine-operation-matrix-2026-07.md`: bảng
  18 dòng × 2 engine (supported/unsupported/failed + detail), lệnh tái tạo (`swift test --filter
  ...MatrixTests`), và 3 dòng kết luận: op nào chuyển vào engine trước (nhóm page ops), op nào chặn
  Linux/Windows. KHÔNG sửa ROADMAP trong lát cắt này.
  → verify: full suite `swift test` → không failure mới (161 pass + tests mới, 7 skip cũ giữ nguyên).
