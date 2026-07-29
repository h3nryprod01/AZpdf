# Code summary — i18n + a11y sub-slice 1: localization infrastructure + 6-file sweep + CI gate

## Step 1 PoC result — THE critical gate — GREEN, sweep proceeded

Plan's step 1 was a hard stop-gate: reproduce the infra in-repo, and only sweep if it's
provably green. It is.

- `swift test --filter LocalizationTests` → **5/5 pass** (bundle declares en+vi; en lproj
  resolves `"Open PDF"`; vi lproj resolves `"Mở PDF"`; en/vi key-set parity; `L(_:)` itself
  returns non-empty).
- Packaged `.app` end-to-end (built via `script/build_and_run.sh --bundle`, run as the real
  binary with a temporary diagnostic print, then reverted):
  - `dist/AZpdf.app/Contents/MacOS/AZpdf -AppleLanguages "(en)"` → `AZPDF_POC_LOCALIZATION_CHECK: Open PDF`
  - `dist/AZpdf.app/Contents/MacOS/AZpdf -AppleLanguages "(vi)"` → `AZPDF_POC_LOCALIZATION_CHECK: Mở PDF`
- This repo's unusual target shape (`path: "."`, explicit `sources:`, explicit `exclude:`)
  was the one thing the planner's standalone PoC package couldn't prove — confirmed here: adding
  `resources: [.process("Resources")]` to that exact target compiles and copies
  `AZpdf_AZpdf.bundle` correctly; no conflict with `sources`/`exclude`.
- Confirmed both required pieces from plan's risk section are load-bearing: without the
  `AZpdf_AZpdf.bundle` copy in `build_and_run.sh`, `Bundle.module` would crash at launch;
  without `CFBundleAllowMixedLocalizations` in Info.plist, `vi` would not be picked even with
  `AppleLanguages` forced (per planner's earlier standalone PoC — not re-broken here since
  both pieces are in place).

**PoC is green → sweep proceeded through steps 2-5.**

## Files changed

New files:
- `Resources/en.lproj/Localizable.strings` — English strings, identity-mapped keys (123 keys)
- `Resources/en.lproj/Localizable.stringsdict` — plural rule for `"%lld pages"` (one/other)
- `Resources/vi.lproj/Localizable.strings` — Vietnamese strings, values preserved verbatim
  from pre-sweep code (123 keys, parity with en)
- `Support/Localization.swift` — `L(_:)` helper + `localizationBundle` (`Bundle.module`)
  accessor, ~15 lines
- `Tests/AZpdfTests/LocalizationTests.swift` — 5 tests: bundle declares en+vi, en/vi lookup
  via direct `Bundle(url:)` (deterministic, doesn't depend on process locale), en/vi key
  parity, `L(_:)` sanity
- `script/audit_i18n_strings.sh` — CI gate (see Step 5 below)

Edited files:
- `Package.swift` — added `defaultLocalization: "en"` to `Package(...)`; added
  `resources: [.process("Resources")]` to the `AZpdf` executable target
- `script/build_and_run.sh` — copy `AZpdf_AZpdf.bundle` into `Contents/Resources` after the
  binary copy; added `CFBundleAllowMixedLocalizations`/`CFBundleLocalizations` to the
  Info.plist heredoc
- `.github/workflows/ci.yml` — new "Audit i18n strings" step (macos-tests job, right after
  "Audit portable core boundary"); added `script/audit_i18n_strings.sh` to the `bash -n` list
- `App/OpenPaperApp.swift` — menu bar sweep, 44 `L(...)` call sites (undo/redo, file, print,
  view/navigate/PDF menus, help, 2 window titles)
- `Models/ShapeAnnotation.swift` — `ShapeKind.label` sweep, 6 `L(...)` call sites
- `Views/ContentView.swift` — toolbar/edit bar/find bar/4 alerts/drop overlay/defaultFilename
  sweep, 68 `L(...)` call sites + 5 a11y modifiers (2 zoom buttons `Image`→`Label`, page
  indicator label, zoom-% label, find-bar chevrons + magnifying-glass hidden)
- `Views/EmptyDocumentView.swift` — 7 `L(...)` call sites + 1 a11y label (Remove-row
  disambiguation by filename)
- `Views/SidebarView.swift` — 8 `L(...)` call sites + 1 a11y modifier (`PageThumbnail` hidden)
- `Views/DocumentPropertiesSheet.swift` — 8 `L(...)` call sites (title, description, 4 form
  fields, Cancel, Apply)

## Steps completed

- [x] 1. PoC hạ tầng in-repo ✓ — green, see above; sweep unblocked
- [x] 2. Sweep menu bar (`OpenPaperApp.swift` + `ShapeAnnotation.swift`) ✓ — build green,
      parity green, 175/7/0
- [x] 3. Sweep ContentView (toolbar/edit bar/find bar/alerts/drop overlay + a11y) ✓ — build
      green, 0 Vietnamese literals left (grep-verified), 175/7/0
- [x] 4. Sweep EmptyDocumentView/SidebarView/DocumentPropertiesSheet + a11y ✓ — build green,
      0 Vietnamese literals left in all 6 files (grep-verified), 175/7/0
- [x] 5. CI gate `audit_i18n_strings.sh` ✓ — self-test green, real audit green, wired into
      `ci.yml`, mutation-checked (see below)
- [ ] 6. Verify tổng + qa-report ✗ — **partially done, left unchecked** — see "Notes for
      tester" below for exactly what's done vs. what's left

## Real verify output

Final full-suite run:
```
$ swift test
Test Suite 'AZpdfPackageTests.xctest' passed.
  Executed 175 tests, with 7 tests skipped and 0 failures (0 unexpected) in 2.762 seconds
```
(170 pre-existing + 5 new `LocalizationTests` = 175; 7 skips unchanged; 0 failures — no
regression.)

Gates:
```
$ ./script/audit_i18n_strings.sh --self-test
i18n audit self-test passed.
$ ./script/audit_i18n_strings.sh
i18n audit passed: no literal Vietnamese strings in swept files.
$ ./script/audit_local_first.sh
Local-first audit passed: no network client API found.
$ ./script/audit_portable_core.sh
Portable-core audit passed: Core remains Foundation-only.
```

Grep for remaining Vietnamese diacritics in all 6 swept files + `Support/Localization.swift`:
zero hits except two `//` comments in `ContentView.swift` (lines 184, 234) that are English
prose *quoting* the pre-sweep Vietnamese term for context (e.g. `// ...toolbar "Chỉnh sửa"
toggle`) — correctly out of scope per plan ("không đổi comment tiếng Việt"), and correctly
ignored by the gate (comment-stripped before the check).

Broad end-to-end string-resolution check (temporary diagnostic in `OpenPaperApp.swift`,
reverted after capture — 12 keys spanning all 5 `L(_:)`-using files plus the
`ShapeAnnotation` model, run through the actual packaged `.app`):

| Key | `-AppleLanguages "(en)"` | `-AppleLanguages "(vi)"` |
|---|---|---|
| Undo | Undo | Hoàn tác |
| About AZpdf | About AZpdf | Giới thiệu về AZpdf |
| Drop PDF to open | Drop PDF to open | Thả PDF để mở |
| Fit Page | Fit Page | Vừa trang |
| Export protected… | Export protected… | Xuất bảo vệ |
| Open a PDF Document | Open a PDF Document | Mở một tài liệu PDF |
| Recent | Recent | Gần đây |
| Table of Contents | Table of Contents | Mục lục |
| Untitled | Untitled | Không tiêu đề |
| Document Properties | Document Properties | Thuộc tính tài liệu |
| Apply | Apply | Áp dụng |
| ShapeKind.rectangle.label | Rectangle | Chữ nhật |

All 12/12 correct in both directions — vi values are byte-for-byte identical to the original
in-code Vietnamese literals (zero-regression requirement met for the strings checked).

## Mutation checks (both required, both done for real)

**1. Gate script (`audit_i18n_strings.sh`)** — injected `let mutationCheckTemp = "Xin chào"`
into `ContentView.swift`:
```
$ ./script/audit_i18n_strings.sh
Views/ContentView.swift:8:    let mutationCheckTemp = "Xin chào"
i18n audit failed: literal Vietnamese string found in an already-swept file...
exit code: 1
```
Reverted → `i18n audit passed... exit code: 0`. Also exercised by the script's own
`--self-test` mode every run (a bare `Text("Xin chào")` fixture must fail, a
`Text(L("Hello")) // chú thích tiếng Việt` fixture must pass, both asserted before the script
even checks the real repo).

**2. `LocalizationTests` parity/lookup** — deleted `"Cancel" = "Hủy";` from
`Resources/vi.lproj/Localizable.strings`:
```
testEnglishAndVietnameseStringsHaveTheSameKeys failed: key sets differ (vi missing "Cancel")
testVietnameseLocaleReturnsVietnameseStrings failed: ("Cancel") is not equal to ("Hủy")
  — i.e. the missing key silently fell back to the English identity value
Executed 5 tests, with 2 failures
```
Restored the line → `swift test` back to 175/7/0.

## Notes for tester

**GUI/VoiceOver walkthrough was not completed by the coder — this subagent invocation had no
computer-use/screenshot tooling available (only Read/Edit/Write/Bash).** What's already solid
and doesn't need re-verifying:
- Every `L(_:)` key actually resolves correctly in both locales through the real packaged
  `.app` (proven for 12 representative keys above, spanning all 6 swept files;
  `LocalizationTests` proves the underlying data for 100% of keys via parity).
- Zero Vietnamese literals remain in the 6 swept files (grep-verified, gate-enforced).
- No layout/behavior change was made anywhere except the 2 zoom buttons
  (`Image`→`Label(systemImage:)`, still icon-only in the toolbar) and new a11y modifiers,
  which don't move pixels.

What's left for the tester (per plan step 6):
1. Write `qa-report/i18n-a11y-slice1-2026-07.md` — a table of view × [en clean / vi
   unchanged / VoiceOver] for: menu bar, toolbar, edit bar, find bar, empty state, sidebar,
   DocumentPropertiesSheet. Include the note "xcstrings does not run under SwiftPM CLI —
   switched to .lproj" so the larger plan's 1a section gets corrected.
2. Actual VoiceOver keyboard walkthrough of the toolbar + edit bar (Cmd+F5, tab through
   controls) — confirm no control reads blank, especially the 2 zoom buttons and the 2
   find-bar chevrons that got new `.accessibilityLabel`s in this slice.
3. Visual pass in Accessibility Inspector on the page-indicator and zoom-% labels (they now
   carry `.accessibilityLabel`s independent of their visible `Text`, worth confirming the
   values read sensibly: "Page 3 of 12", "Zoom 150 percent").
4. Test fixtures available: `Tests/Fixtures/source/two-page.pdf`,
   `Tests/Fixtures/source/annotated-highlight-ink.pdf` — good for exercising the sidebar page
   list + properties sheet.
5. Launch commands: `SWIFT_CONFIGURATION=debug script/build_and_run.sh --bundle`, then
   `open -n dist/AZpdf.app --args -AppleLanguages "(en)"` (or `"(vi)"`) for a normal
   frontmost GUI app with a visible menu bar — plain binary invocation also works but won't
   reliably front the app/menu bar.

## Notes for reviewer

- **`Export protected…`** (`ContentView.swift` edit-bar label) is deliberately sentence-case
  with an ellipsis per the orchestrator's explicit example (`"Xuất bảo vệ" → "Export
  protected…"`), even though its sibling edit-bar labels are Title Case with no ellipsis
  (e.g. "Rotate", "Duplicate") and the source Vietnamese has no `…` either. Flagged in case
  this reads as inconsistent — happy to align it to Title Case ("Export Protected") if that's
  preferred; I followed the literal instruction.
- **`kind.label` (`ShapeAnnotation.swift`) is also written into the saved PDF's annotation
  `/Contents`** (`ShapeAnnotationFactory.make`, same file, unchanged call site). Before this
  slice it was always Vietnamese; now it follows the app's active locale. Under `en`, newly
  created/resized shapes get English content metadata — a reasonable, intended consequence of
  localizing a shared property, not a bug, but it's a *data* side effect (not just UI) worth
  the reviewer's awareness. No test asserts the literal string value here (checked
  `ShapeAnnotationTests.swift` — only geometry/structural assertions), so nothing broke.
- **Two out-of-scope files consume the now-locale-aware `kind.label`** and will show
  mixed-language output under `en` until their own sub-slice sweeps them:
  `Views/AnnotationEditPopover.swift:92` (`"Chỉnh sửa \(kind.label.lowercased())"`) and
  `Stores/DocumentStore+Annotations.swift:125` (`"Nhấp vào PDF để đặt
  \(kind.label.lowercased())."`). Both were explicitly out of scope for this slice (Stores/
  and the ~14 remaining views); flagging so it's not mistaken for a new bug when the tester
  hits it under `en`.
- **Optional a11y hints skipped on purpose**: plan explicitly marks `.accessibilityHint` on
  the two destructive actions (edit-bar Redact, sidebar context-menu "Delete Page") as
  "không bắt buộc... không over-engineer." Skipped both — their `Text` labels are already
  read by VoiceOver via the standard Button/Label path, hints would only be a nice-to-have.
- **`Packaging/flatpak/*` "unhandled files" build warning is pre-existing**, not introduced by
  this change — those files were never in the `AZpdf` target's `sources`/`exclude`/`resources`
  before this slice either. Left untouched (out of scope, unrelated to i18n).
- **Key-reuse by design**: since keys are the literal English text (English-as-key, per plan),
  identical English strings across files automatically share one `.strings` entry (e.g.
  `"Cancel"`, `"Fit Page"`, `"Open PDF"`, `"Undo"` are each defined once and used from 2-3
  call sites). This is intentional, not accidental duplication.
- **`Support/Localization.swift` is intentionally minimal** (2 declarations, ~15 lines) — no
  wrapper types, no pluralization helpers beyond the one `.stringsdict` entry proven in the
  PoC. Later sub-slices needing more plurals should follow the same `.stringsdict` +
  identity-map pattern already established, not add new infrastructure.

## Views/areas left for the next sub-slice (per plan's explicit "Out of scope")

Views (~14): `PDFReaderView`, `DocumentInspectorView`, `AnnotationEditPopover`, `HelpView`,
`AboutView`, `SettingsView`, `WorkspaceView`, `OCRSheet`, `SignatureSheet`,
`CertificateSignatureSheet`, `PAdESSigningSheet`, `PDFConformanceSheet`,
`PasswordProtectSheet`, `TextAnnotationSheet`.

Plus: all of `Stores/` + `Services/` (dynamic error/status messages, `windowTitle`,
`lastError`, `placementInstruction`, verification messages — e.g.
`Stores/DocumentStore.swift:122,128` "Chưa mở tài liệu" / "Đã chỉnh sửa"); README bilingual
docs; `AZpdfEngineCLI` messages; Shell/Linux (Flutter has its own i18n system).

To extend the gate for the next sub-slice: add each newly-swept file's path to the
`SWEPT_FILES` array in `script/audit_i18n_strings.sh` (one line each) — everything else in
the script (comment-stripping, VN character class, self-test) is already general-purpose and
needs no changes.

## Deviations from plan

None. Followed the plan's approach (`.lproj` + `Bundle.module`, English-as-key, single `L(_:)`
helper) exactly as specified; no architecture changes.
