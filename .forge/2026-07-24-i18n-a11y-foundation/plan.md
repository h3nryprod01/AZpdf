# Plan — i18n + a11y sub-slice 1: hạ tầng localization SwiftPM + sweep nhóm view "bộ mặt app" (menu bar, toolbar, edit bar, empty state, sidebar, 1 sheet)

## Goal

Sau slice này: (1) hạ tầng i18n chạy thật dưới `swift build` CLI được chứng minh bằng test xanh
`en`+`vi`; (2) mở app với locale `en` → menu bar, toolbar, edit bar, find bar, alert tĩnh,
empty state, sidebar, DocumentPropertiesSheet hiển thị 100% tiếng Anh; locale `vi` → giữ nguyên
từng chữ như hiện tại; (3) mọi control trong nhóm view đó có nhãn VoiceOver có nghĩa; (4) CI gate
chặn literal tiếng Việt mới lọt vào file đã sweep. Các sub-slice sau chỉ còn lặp cơ khí bước
sweep trên ~14 view còn lại + Stores/Services.

## Context discovered

- **Hiện trạng đúng như plan lớn**: 0 `NSLocalizedString`, 0 `.lproj`/`.xcstrings`, không có
  `defaultLocalization` trong `Package.swift`; đúng 1 accessibility modifier toàn app
  (`Views/OCRSheet.swift:37`).
- **Quy mô chuỗi** (số DÒNG chứa ký tự VN có dấu, gồm cả comment): `Views/ContentView.swift` 55,
  `App/OpenPaperApp.swift` 42, `AnnotationEditPopover` 33, `DocumentInspectorView` 27, `HelpView` 18,
  `OCRSheet` 14, `SettingsView` 12, các sheet còn lại 4-9 mỗi file. Tổng Views+App+Stores ≈ 300 dòng.
- **App target đặc thù**: `Package.swift:63-69` — target `AZpdf` có `path: "."`, `sources:` liệt kê
  tường minh, chưa có `resources:`. Build/chạy qua `script/build_and_run.sh` (KHÔNG có Xcode project).
- **`build_and_run.sh:32` chỉ copy binary trần** vào `Contents/MacOS` — không copy resource bundle
  SwiftPM nào; Info.plist sinh bằng heredoc tại dòng 60-80 (sửa được dễ).
- **Toolbar**: hầu hết nút đã dùng `Label(title:systemImage:)` → VoiceOver đọc được title (chỉ cần
  localize); nhưng 2 nút zoom (`ContentView.swift:323,326`) là `Image(systemName:)` trần — vô nghĩa
  với VoiceOver; page indicator (dòng 317) và zoom % (dòng 324) là Text động không nhãn ngữ nghĩa;
  2 nút mũi tên find bar (155-160) chỉ có `.help`.
- **Shape popover trong ContentView dùng `ShapeKind.label`** (`Models/ShapeAnnotation.swift:23-29`,
  6 chuỗi VN) — phải localize kèm, nếu không ContentView không sạch được.
- **Khuôn mẫu gate**: `script/audit_local_first.sh` (rg + exit 1) và chỗ wiring CI:
  `.github/workflows/ci.yml` job macos-14, sau dòng 21 (`audit_portable_core.sh`).
- **Chuỗi động từ Store** (windowTitle, lastError, placementInstruction, verification messages)
  hiển thị trong ContentView nhưng nguồn ở Stores/Services — để slice sau.

## Rủi ro hạ tầng — ĐÃ KIỂM BẰNG PoC THẬT (không còn là giả định)

Planner đã dựng package PoC và chạy trên đúng toolchain máy này (Swift 6.3.3, swift-tools 6.0):

1. **`.xcstrings` KHÔNG hoạt động dưới `swift build` CLI.** SwiftPM copy file thô vào bundle
   (`poc_poc.bundle/Localizable.xcstrings`), runtime Foundation không đọc — forced `vi` vẫn ra
   tiếng Anh. String Catalog là tính năng compile của Xcode build system. **→ Không dùng .xcstrings.**
2. **`.lproj/Localizable.strings` + `.stringsdict` HOẠT ĐỘNG** qua `resources: [.process("Resources")]`
   + `defaultLocalization: "en"`: bundle build đúng `en.lproj`/`vi.lproj`, plural `.stringsdict` chạy
   (`1 page`/`3 pages`/`3 trang` đều đúng).
3. **Gotcha quyết định thành bại**: process có main bundle không khai báo localization sẽ ghim
   `preferredLocalizations = [en]` dù `AppleLanguages = (vi)`. Fix đã verify: thêm
   `CFBundleAllowMixedLocalizations = true` vào Info.plist của .app → `vi` ăn ngay
   (PoC: "Mở tài liệu", "3 trang"). Đồng thời `Bundle.module` tìm thấy bundle khi copy vào
   `Contents/Resources/` của .app.

Kết luận: hạ tầng chạy, nhưng cần đúng 3 mảnh: `.lproj` resources trong Package.swift,
copy `AZpdf_AZpdf.bundle` vào app, và `CFBundleAllowMixedLocalizations` trong Info.plist.
Bước 1 tái lập PoC này ngay trong repo làm chốt chặn — **nếu bước 1 đỏ thì DỪNG, báo lại,
không sweep**.

## Phạm vi sub-slice này

**Sweep (6 file nguồn):** `App/OpenPaperApp.swift`, `Views/ContentView.swift`,
`Views/EmptyDocumentView.swift`, `Views/SidebarView.swift`, `Views/DocumentPropertiesSheet.swift`
(sheet tiêu biểu — chứng minh pattern trên Form/sheet), `Models/ShapeAnnotation.swift` (chỉ
property `label`). ≈ 110 key. Đây là "mặt hoàn chỉnh": mọi thứ user thấy từ lúc mở app đến lúc
bấm nút đầu tiên, cộng toàn bộ menu bar (bề mặt bàn phím/VoiceOver số 1).

**Hạ tầng:** `Package.swift`, `Resources/en.lproj/` + `Resources/vi.lproj/` (mới),
`Support/Localization.swift` (mới), `script/build_and_run.sh`, `script/audit_i18n_strings.sh` (mới),
`.github/workflows/ci.yml`, `Tests/AZpdfTests/LocalizationTests.swift` (mới).

**KHÔNG làm trong slice này** (để sub-slice sau, lặp cơ khí): các view còn lại —
`PDFReaderView`, `DocumentInspectorView`, `AnnotationEditPopover`, `HelpView`, `AboutView`,
`SettingsView`, `WorkspaceView`, `OCRSheet`, `SignatureSheet`, `CertificateSignatureSheet`,
`PAdESSigningSheet`, `PDFConformanceSheet`, `PasswordProtectSheet`, `TextAnnotationSheet`;
toàn bộ chuỗi trong `Stores/` + `Services/` (error/status message động); README song ngữ;
message của `AZpdfEngineCLI`; comment tiếng Việt (giữ nguyên — không phải UI).

## Approach

`en.lproj`/`vi.lproj` `Localizable.strings` (+`.stringsdict` khi cần plural) — đường duy nhất
PoC chứng minh chạy dưới SwiftPM CLI. **English-as-key**: code viết chuỗi Anh trực tiếp, `en` là
default + fallback, `vi` giữ nguyên từng chữ bản hiện tại (người dùng vi zero regression). Một
helper duy nhất `L(_:)` trả `String` để CÙNG MỘT pattern dùng được cho `Text`, `.help`, `Button`,
alert, filename — sweep thành thao tác thay thế thuần cơ khí.

## Alternatives considered

- **`.xcstrings` String Catalog** (đề xuất gốc của plan lớn 1a): loại bỏ bằng bằng chứng PoC —
  SwiftPM CLI không compile nó, runtime bỏ qua. Lợi ích duy nhất (Xcode editor sync) vô nghĩa vì
  repo không có Xcode project. Plan lớn cần đính chính điểm này khi thực thi.
- **Compile .xcstrings bằng `xcstringstool` qua build plugin/pre-build script**: thêm tooling +
  file sinh ra + phụ thuộc Xcode toolchain nội bộ không cam kết — đắt hơn hẳn việc viết tay 2 file
  .strings mà không mua thêm gì.
- **Semantic key (`toolbar.save`)**: key hỏng thì UI hiện key thô (dễ thấy bug) nhưng code khó đọc,
  phải duy trì 3 nơi (code + en + vi) thay vì 2, và fallback xấu. English-as-key cho fallback tự
  nhiên + code tự tài liệu.

## Cách sweep (quy ước cho coder)

- **Helper** `Support/Localization.swift`:
  `func L(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: .module) }`
  kèm `let localizationBundle = Bundle.module` (internal — test cần accessor này vì `Bundle.module`
  viết trong file test sẽ trỏ nhầm sang bundle của test target).
- **Thay thế**: `Text("Mở PDF")` → `Text(L("Open PDF"))`; `Button("Hủy")` → `Button(L("Cancel"))`;
  `.help("Lưu (⌘S)")` → `.help(L("Save (⌘S)"))`; `Label("Xoay", systemImage:)` →
  `Label(L("Rotate"), systemImage:)`. Các API này đều có overload `StringProtocol`. Nếu gặp API
  chỉ nhận `LocalizedStringKey` không kèm bundle, dùng overload `Text`: `.help(Text(...))` — đừng
  để lookup rơi vào main bundle.
- **Nội suy**: `L("\(count) pages")` sinh key `"%lld pages"`; entry vi: `"%lld pages" = "%lld trang";`.
  Plural en (page/pages) dùng `.stringsdict` en.lproj (PoC đã chứng minh chạy). Chuỗi 2 tham số như
  `"Trang \(i+1)"`, `Section("Trang — \(n)")`, defaultFilename `"\(title)-trang-\(n)"` → key dạng
  `"Page %lld"`, `"Pages — %lld"`, `"%@-page-%lld"` (positional `%1$@` khi vi đảo trật tự).
- **File .strings**: mỗi key một dòng, sắp theo alphabet, comment `/* */` theo cụm view — en.lproj
  là identity map (`"Open PDF" = "Open PDF";` — BẮT BUỘC có, để bundle khai báo đủ 2 localization,
  nếu chỉ có vi.lproj thì vi thắng cả với user tiếng Anh).
- **Chất lượng tiếng Anh — người quyết đã yêu cầu**: dịch NGHĨA, đọc tự nhiên như app macOS bản xứ,
  theo thuật ngữ Apple HIG: Undo/Redo, Save/Save As…, Duplicate Page, Rotate Right, Fit Page,
  Show/Hide Inspector, "Drop PDF to open". KHÔNG transliterate, không máy dịch mù. Bản vi = copy
  nguyên văn chuỗi đang có trong code hôm nay.
- Phím tắt (`keyboardShortcut`) giữ nguyên — chỉ đổi title.

## a11y trong cùng sweep (mỗi view đụng đúng một lần)

Nhãn a11y cũng qua `L()` — localize luôn trong cùng lượt. Cụ thể:

- `ContentView.swift:323,326` — 2 nút zoom `Image` trần → đổi thành
  `Label(L("Zoom Out")/L("Zoom In"), systemImage:)` cho đồng bộ với các nút toolbar anh em
  (được VoiceOver miễn phí, không đổi hình thức hiển thị vì toolbar chỉ hiện icon).
- `ContentView.swift:317` page indicator → `.accessibilityLabel(L("Page \(x) of \(y)"))`;
  dòng 324 zoom % → `.accessibilityLabel` tương ứng ("Fit page" / "Zoom %lld percent").
- Find bar: `Image "magnifyingglass"` (146) → `.accessibilityHidden(true)` (trang trí);
  2 nút chevron (155-160) → `.accessibilityLabel(L("Previous result")/L("Next result"))`.
- Edit bar `editTool`: Button chứa VStack(Image+Text) — VoiceOver đã đọc Text; thêm
  `.accessibilityHint` KHÔNG bắt buộc, chỉ thêm cho 2 nút phá hủy (Redact, Xóa trang context menu)
  nếu tiện. Không over-engineer.
- `SidebarView`: `PageThumbnail` → `.accessibilityHidden(true)` (row đã có Text "Page N");
  outline row là Button+Text — đủ.
- `EmptyDocumentView`: nút "Xóa" mỗi hàng recent →
  `.accessibilityLabel(L("Remove \(name) from Recents"))` để phân biệt hàng.
- Menu bar (`OpenPaperApp`): Button title = nhãn a11y sẵn — chỉ cần localize.
- Bàn phím: mọi control đều là Button/TextField chuẩn SwiftUI — đã focusable, không cần thêm.

## Rủi ro & đánh đổi

- **Regress UI khi thay literal**: sweep thuần cơ khí, không đổi layout; 161 test hiện có + lái GUI
  đối chiếu từng bề mặt sau sweep (vi phải y hệt trước sweep — so bằng mắt theo checklist bước 6).
- **Bản dịch sai nghĩa/ngượng**: en là bản viết tay theo HIG; reviewer đọc toàn bộ en.lproj như một
  tài liệu (110 dòng, 10 phút). Nghi ngờ chỗ nào ghi chú chỗ đó trong PR.
- **Gate báo nhầm**: xử lý bằng thiết kế ở bước 5 (chỉ soi file đã sweep — allowlist trong script;
  strip comment `//` trước khi grep nên comment VN hợp lệ không bị bắt). Góc chết chấp nhận được:
  chuỗi chứa `https://` rồi VN phía sau trên cùng dòng bị strip nhầm → false-NEGATIVE hiếm, không
  chặn ai; block comment `/* */` chứa VN có thể false-positive → quy ước dùng `//` trong file đã sweep.
- **Chuỗi động từ Store vẫn tiếng Việt** dưới locale en (lastError, placementInstruction,
  windowTitle "Chưa có tài liệu"...) — chấp nhận có chủ đích, là phạm vi sub-slice Stores/Services
  kế tiếp; tiêu chí "0 VN" của slice này chỉ tính literal tĩnh trong 6 file sweep.
- **`swift test` trên CI locale Anh**: không test qua locale process — test load trực tiếp từng
  `.lproj` bằng `Bundle(url:)` nên deterministic mọi máy.
- **Package target `path: "."` + `sources` tường minh** là cấu hình ít gặp — chính là lý do bước 1
  PoC-in-repo phải chạy trước khi sweep.

## Các bước

- [x] 1. **PoC hạ tầng in-repo — chốt chặn, fail thì DỪNG.**
  (a) `Package.swift`: thêm `defaultLocalization: "en"` vào `Package(...)` và
  `resources: [.process("Resources")]` vào target `AZpdf` (dòng 63-69).
  (b) Tạo `Resources/en.lproj/Localizable.strings` + `Resources/vi.lproj/Localizable.strings` với
  3 key thật dùng ngay: `"Open PDF"`, `"Cancel"`, `"%lld pages"` (kèm `.stringsdict` en cho plural).
  (c) `Support/Localization.swift`: hàm `L(_:)` + `localizationBundle` như quy ước trên.
  (d) `Tests/AZpdfTests/LocalizationTests.swift`: assert `localizationBundle.localizations` ⊇
  {en, vi}; load từng lproj qua `Bundle(url:)` → `"Open PDF"` ra `"Open PDF"` (en) và `"Mở PDF"` (vi);
  test parity: đọc 2 file .strings bằng `NSDictionary(contentsOf:)`, assert set key en == set key vi.
  (e) `script/build_and_run.sh`: sau dòng 32 copy thêm
  `$(swift build ... --show-bin-path)/AZpdf_AZpdf.bundle` → `$APP_RESOURCES/`; thêm
  `<key>CFBundleAllowMixedLocalizations</key><true/>` và
  `<key>CFBundleLocalizations</key><array><string>en</string><string>vi</string></array>`
  vào heredoc Info.plist (dòng 60-80).
  → verify: `swift test --filter LocalizationTests` xanh; `SWIFT_CONFIGURATION=debug
  script/build_and_run.sh --bundle` rồi chạy `dist/AZpdf.app/Contents/MacOS/AZpdf -AppleLanguages "(en)"`
  và `"(vi)"` — chuỗi test đổi ngôn ngữ đúng (dùng tạm 1 chỗ gọi `L("Open PDF")` nếu cần nhìn bằng mắt).
  **Nếu bất kỳ ý nào fail → dừng, báo, không sang bước 2.**
- [x] 2. **Sweep menu bar**: `App/OpenPaperApp.swift` (~35 chuỗi: undo/redo, file, print, view,
  navigate, PDF menu, help, 2 Window title) + `Models/ShapeAnnotation.swift` property `label`
  (6 chuỗi). Append key vào cả en/vi .strings.
  → verify: `swift build` xanh; parity test xanh; chạy app `-AppleLanguages "(en)"` → toàn bộ
  menu bar tiếng Anh; `"(vi)"` → y hệt trước sweep.
- [x] 3. **Sweep ContentView** (`Views/ContentView.swift`, ~45 chuỗi: toolbar, edit bar, find bar,
  4 alert, drop overlay, defaultFilename) + toàn bộ mục a11y của ContentView/find bar ở §a11y.
  → verify: build xanh; app en → toolbar/edit bar/alert tĩnh 0 chuỗi VN; Accessibility Inspector
  (Xcode devtools) trỏ vào 2 nút zoom + page indicator đọc ra nhãn có nghĩa.
- [x] 4. **Sweep 3 view còn lại**: `Views/EmptyDocumentView.swift`, `Views/SidebarView.swift`
  (gồm `"Không tiêu đề"` dòng 79), `Views/DocumentPropertiesSheet.swift` + mục a11y tương ứng
  (thumbnail hidden, nút Remove recent có nhãn theo tên file).
  → verify: build + full `swift test` xanh; app en: màn hình launch, sidebar (mục lục + trang +
  context menu), sheet Thuộc tính — 0 chuỗi VN tĩnh.
- [x] 5. **CI gate** `script/audit_i18n_strings.sh` (khuôn theo `audit_local_first.sh`):
  biến `SWEPT_FILES` = đúng 6 file đã sweep + `Support/Localization.swift`; với mỗi file:
  strip comment (`sed 's|//.*$||'`) rồi grep ký tự VN có dấu (character class liệt kê tường minh
  cả hoa lẫn thường — BSD grep không có `\p{...}`) trên dòng còn chứa `"`; hit → in file:line,
  exit 1. Thêm mode `--self-test`: sinh 2 file tạm — một chứa `Text("Xin chào")` phải FAIL, một chứa
  `Text(L("Hello")) // chú thích tiếng Việt` phải PASS — rồi chạy chính gate trên repo phải PASS.
  Wire vào `.github/workflows/ci.yml` job macos-14 sau `audit_portable_core.sh` (dòng 21):
  `./script/audit_i18n_strings.sh --self-test && ./script/audit_i18n_strings.sh`; thêm script vào
  danh sách `bash -n` (dòng 26).
  → verify: `script/audit_i18n_strings.sh --self-test` xanh; gate chạy trên repo exit 0; mutation
  check thủ công: thêm tạm `Text("Xin chào")` vào ContentView → gate ĐỎ; gỡ → xanh (ghi vào commit).
- [ ] 6. **Verify tổng + checklist a11y.** Full `swift test` (161 + mới, không failure mới);
  mutation check parity test: xóa tạm 1 key khỏi vi.lproj → LocalizationTests ĐỎ, khôi phục → xanh;
  lái GUI cả 2 locale theo checklist: en (menu, toolbar, edit bar, find, empty, sidebar, properties
  sheet — 0 VN tĩnh), vi (y hệt bản trước sweep); bật VoiceOver đi hết toolbar + edit bar bằng
  bàn phím — không control nào đọc trống. Ghi kết quả vào
  `qa-report/i18n-a11y-slice1-2026-07.md` (bảng view × [en sạch / vi nguyên trạng / VoiceOver]),
  kèm ghi chú "xcstrings không chạy dưới SwiftPM CLI — đã chuyển .lproj" để plan lớn 1a đính chính.
  → verify: file qa-report tồn tại, checklist đủ 6 bề mặt, không mục nào FAIL.

## Đo bằng gì (đạt / không đạt)

- `swift test` xanh toàn bộ; `LocalizationTests` chứng minh en+vi load đúng qua bundle SwiftPM,
  parity key en == vi.
- Chạy `dist/AZpdf.app` với `-AppleLanguages "(en)"`: 6 bề mặt đã sweep **0 chuỗi VN tĩnh**;
  với `"(vi)"`: từng chữ y như trước sweep.
- `script/audit_i18n_strings.sh`: self-test xanh; repo xanh; thêm 1 literal VN vào file đã sweep
  → ĐỎ (mutation check ghi trong commit message).
- VoiceOver đọc nhãn có nghĩa cho: mọi nút toolbar (kể cả 2 nút zoom), page indicator, find bar,
  mọi nút edit bar, hàng recent + nút xóa, thumbnail row — verify GUI thủ công, ghi vào qa-report.
- `script/audit_local_first.sh` + `script/audit_portable_core.sh` vẫn xanh (không đụng Core,
  không thêm network API).

## UI surfaces

None — chỉ localize chuỗi + thêm nhãn a11y, không đổi layout. (Ngoại lệ danh nghĩa: 2 nút zoom
đổi từ `Image` trần sang `Label` — toolbar macOS vẫn hiển thị icon-only, không đổi pixel.)

## Out of scope

- ~14 view còn lại + toàn bộ chuỗi Stores/Services (sub-slice 2-3: mỗi lượt 4-6 view, chỉ lặp
  bước 2-4 + append `SWEPT_FILES`).
- README/docs song ngữ; message `AZpdfEngineCLI`; Shell/Linux (Flutter có hệ i18n riêng).
- Không thêm ngôn ngữ thứ 3; không đổi comment tiếng Việt trong code; không refactor view nào.
