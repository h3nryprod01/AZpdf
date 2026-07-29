# Review — i18n + a11y sub-slice 1 + Settings (commit 3ac98de)

## Verdict
APPROVE WITH FIXES

Re-verified after fixes: `swift build` green, `swift test` **182 pass / 7 skip / 0 fail**,
`audit_i18n_strings.sh --self-test` + gate + `audit_local_first.sh` + `audit_portable_core.sh`
+ `bash -n` all exit 0. Key parity 143 en == 143 vi (removed 1 dead key, added 1).

## Auto-applied

### Translation fixes (key | cũ | mới | lý do)

| Key (code + en + vi) | Cũ | Mới | Lý do |
|---|---|---|---|
| `No results` (was `None`) | en "None" / vi "Không có" | en "No results" / vi giữ "Không có" | Find-bar khi 0 kết quả. "None" đứng một mình cạnh ô tìm kiếm đọc như bản dịch word-by-word của "Không có"; "No results" là register chuẩn của search UI macOS (Spotlight). `ContentView.swift:159` đổi key theo. |
| `Reload Plugins` (was `Reload plugins`) | "Reload plugins" | "Reload Plugins" | Push button → Title Case theo HIG; các nút anh em ("Save As", "Delete Page", "Open PDF…") đều Title Case. vi giữ "Tải lại plugin". `SettingsView.swift:44` đổi key theo. |
| `OK` (mới) | `Button("OK", ...)` literal | `Button(L("OK"), ...)` + `"OK" = "OK";` cả 2 bảng | 2 alert verify (`ContentView.swift:123,128`) còn literal sót trong file đã sweep. Hôm nay en=vi="OK" nên vô hại, nhưng ngôn ngữ thứ 3 sẽ không (es: "Aceptar"). |

### Code/infra fixes

- **MEDIUM — dead keys do chính commit này tạo**: `"%@-page-%lld"` (en) / `"%@-trang-%lld"` (vi)
  mồ côi sau khi commit tự gỡ `L()` khỏi defaultFilename (đúng đắn). Đã xóa cả hai — nếu để lại,
  ngày nào đó ai đó re-wire là filename export đổi theo locale. Parity giữ nguyên.
- **LOW — comment sai thực tế** `App/OpenPaperApp.swift:10-14`: viết "Menu bar commands …
  are not rebuilt — Settings says so" trong khi (a) GUI đã verify menu bar ĐỔI ngay, (b) chuỗi
  Settings thực tế nói "Applies immediately — no restart needed." không có caveat nào. Comment
  stale từ iteration trước; đã viết lại đúng cơ chế (@AppStorage → Scene body re-eval → commands
  rebuild; `.id` → window tree rebuild).
- **LOW — gate báo sai số dòng**: `scan_file` đánh số dòng SAU khi `rg -v 'i18n-exempt:'` lọc,
  nên hit nằm dưới dòng exempt bị lệch số. Đã đảo pipeline (đánh số trước). Mutation-verify:
  literal VN chèn ở `Support/Localization.swift:69` giờ báo đúng `:69` (code cũ báo `:67`).
- **LOW — thứ tự alphabet**: "Applies immediately — no restart needed." bị append cuối cụm
  SettingsView ở cả en/vi (file tự nhận sắp alphabet); đã dời về đúng chỗ.

## Needs decision (CRITICAL / HIGH)

Không có. Không tìm thấy lỗi correctness/security nào ở mức CRITICAL/HIGH.

## Đã đọc toàn bộ 143 cặp en ↔ vi — kết quả

Chất lượng en nhìn chung ĐẠT: thuật ngữ menu đúng HIG (Undo/Redo, Save As…, Print…, Close Tab,
menu "Go" theo Finder), ellipsis dùng đúng chỗ — kể cả chỗ tinh tế: "Verify PAdES Signature"
KHÔNG có "…" (chạy ngay trên tài liệu hiện tại) trong khi "Verify .p7s Signature…" CÓ (phải chọn
file) — đúng quy tắc HIG. Title case cho nút/menu, sentence case cho mô tả/toggle nhất quán.
Thuật ngữ PDF chuyên ngành chính xác: Redact, rasterize, PAdES, conformance, annotation, metadata.
Không chuỗi nào lộ dấu word-by-word ngoài "None" (đã sửa). Không chuỗi nào dài tới mức nguy cơ
vỡ layout (đã so độ dài en/vi từng cặp; chuỗi dài nhất là caption/alert body tự wrap).

**Literal cố ý, xác nhận hợp lệ (không sửa)**: `WindowGroup("AZpdf")`, `.alert("AZpdf")` (tên app),
`CommandMenu("PDF")` (mọi ngôn ngữ như nhau), `Text("AGPL-3.0")` (mã giấy phép), fallback
`?? "PDF"` (nhãn trang), "English"/"Tiếng Việt" tự viết bằng chính nó kèm marker. `grep -rn
i18n-exempt`: đúng 2 chỗ trong repo, đều là tên ngôn ngữ — không bị lạm dụng.

## a11y (6 file đã sweep)

Đủ theo plan: toàn bộ nút toolbar là `Label(L(...), systemImage:)` (gồm 2 nút zoom đã đổi từ
`Image` trần); page indicator + zoom-% có `.accessibilityLabel` qua `L()`; 2 chevron find bar có
nhãn + kính lúp `.accessibilityHidden(true)`; `PageThumbnail` hidden (row đã có "Page N"); nút
Remove recent phân biệt theo tên file. Không còn control icon-only thiếu nhãn trong 6 bề mặt.
Mọi nhãn đều qua `L()`. Không nhãn nào lặp vô nghĩa tên icon.

## Perf `L(_:)` (mục 9 — ĐÃ ĐO, không đoán)

10.000 call qua bundle thật: **0,8 µs/call** key thường, **8,4 µs/call** key nội suy
(`L("Page \(i)")`). Sidebar dùng `List` (row lazy) — rebuild ~50 row hiển thị < 0,5 ms.
UserDefaults + `Bundle(path:)` đều cache nội bộ. Không phải vấn đề; không tối ưu gì.

## Test gaps

- Coder tự khai: `locale:` pin trong `L()` cho plural không kiểm được trên máy này (chỉ đỏ trên
  host có quy tắc số nhiều khác). Chấp nhận — đã có comment giải thích tại chỗ.
- Chưa có test khẳng định en.lproj là identity map (key == value). Nếu ai đổi value en mà quên
  key, fallback English-as-key lệch im lặng. Đề nghị thêm 3 dòng vào LocalizationTests ở
  sub-slice sau (không thêm bây giờ để giữ diff review nhỏ).
- `testUnsetPreferenceFollowsTheSystem` xóa key UserDefaults không khôi phục — vô hại (domain
  của xctest host, không phải của .app; các test pin khác tự set trước khi đọc), ghi nhận thôi.

## Punts (không chặn, không tự sửa)

- "Check PDF/A & PDF/UA…" — "Validate" mới là thuật ngữ ngành conformance (veraPDF). "Check"
  không sai; cân nhắc "Validate PDF/A & PDF/UA…" nếu muốn register pro hơn.
- "Show/Hide Inspector" — HIG chuộng title động "Show Inspector"/"Hide Inspector"; dạng gộp
  tĩnh chấp nhận được, để nguyên.
- "Oval" (en) vs "Hình tròn" (vi = hình tròn, không phải oval) — vi giữ nguyên văn theo luật
  zero-regression; shape vẽ ra là ellipse nên en đúng nghĩa hơn vi. Sửa vi (→ "Hình bầu dục"?)
  khi nào cho phép đụng bản vi.
- Edit-bar "Verify" đứng cạnh "Sign .p7s"/"Sign PAdES" mà không nói verify cái gì; cân nhắc
  "Verify PAdES" nếu bề rộng cho phép.
- Find-bar count `Text("3/12")` chưa có accessibilityLabel — VoiceOver đọc "3/12" thô; "Result
  3 of 12" đẹp hơn, để sub-slice sau.
- Gate blind spot (by design, đã biết): literal tiếng Anh không qua `L()` thì scan dấu VN không
  bắt được; `scan_missing_keys` bù được một phần (key L() không có entry). Mỗi sub-slice vẫn cần
  một lượt grep tay như lượt này.
- `.id(appLanguage)` rebuild toàn bộ view tree khi đổi ngôn ngữ → mất @State tạm (popover shape
  đang mở, v.v.). Cosmetic, đúng thiết kế.
- `code-summary.md` trong state dir stale so với commit cuối (123 key/175 test — trước phần
  Settings); commit message mới là số đúng. Không phải bug.
