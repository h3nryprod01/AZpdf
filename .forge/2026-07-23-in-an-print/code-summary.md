# Code summary — Lát cắt 1c: In ấn cho AZpdf (⌘P qua PDFDocument.printOperation)

## Files changed
- `Stores/DocumentStore+Printing.swift` (new) — `makePrintOperation()` builder
  (document → configured `NSPrintOperation`, untouched/unrun) and
  `printDocument()` runner (`runModal` on key window, `.run()` fallback).
- `App/OpenPaperApp.swift` — added `CommandGroup(replacing: .printItem)` with
  "In…" / ⌘P, right after the existing `.newItem` group (which was not
  touched). Gated on `document == nil`, same pattern as "Lưu"/"Lưu thành…".
- `Views/HelpView.swift` — one `GridRow` added to the "Phím tắt" table:
  `In tài liệu` / `⌘P`, placed after the "Lưu" row.
- `Tests/AZpdfTests/DocumentPrintingTests.swift` (new) — 4 tests covering the
  builder's nil-guard, its configuration, a full headless print-to-file
  round trip, and the `shouldPrint` assumption pin.

## Steps completed
- [x] 1. Store extension (`makePrintOperation()` + `printDocument()`) ✓ — `swift build` green.
- [x] 2. Menu ⌘P + Help row ✓ — `swift build` green; `.newItem` group untouched, `.printItem` used for correct File-menu placement.
- [x] 3. Tests (`DocumentPrintingTests.swift`, 4 cases) ✓ — `swift test --filter DocumentPrintingTests`: 4/4 pass, including the headless end-to-end print (not just the probe script — this ran for real in this test run).
- [x] 4. Mutation check ✓ — see below.
- [ ] 5. GUI verify + qa-report — **not done by design**. Out of coder scope (plan/task explicitly reserves this for manual GUI driving after this step). See "Notes for tester" below for the exact checklist and current file state.

## Verify output (real, pasted)

Targeted test run (4/4 pass):
```
Test Suite 'DocumentPrintingTests' started
Test Case '...testAppCreatedAnnotationsPrintByDefault]' passed (0.001 seconds)
Test Case '...testMakePrintOperationConfiguresJobTitleAndPanelFlags]' passed (0.059 seconds)
Test Case '...testMakePrintOperationReturnsNilWithoutDocument]' passed (0.000 seconds)
Test Case '...testPrintOperationRunsHeadlessAndProducesAllPages]' passed (0.130 seconds)
Test Suite 'DocumentPrintingTests' passed
	 Executed 4 tests, with 0 failures (0 unexpected)
```

Full suite (`swift test`), final run after mutation check restored:
```
Test Suite 'AZpdfPackageTests.xctest' passed
	 Executed 170 tests, with 7 tests skipped and 0 failures (0 unexpected) in 4.236 seconds
```
Baseline was 166 pass / 7 skip; 170 = 166 + 4 new tests. Skip count unchanged
(7). Zero failures — no regression.

## Mutation check (kỷ luật repo)

1. **Removed** `operation?.jobTitle = title` from `makePrintOperation()`
   → `swift test --filter DocumentPrintingTests`:
   ```
   error: -[...testMakePrintOperationConfiguresJobTitleAndPanelFlags] :
   XCTAssertEqual failed: ("nil") is not equal to ("Optional("two-page")")
   Executed 4 tests, with 1 failure
   ```
   **RED**, as expected. Restored the line, re-ran → 4/4 **GREEN**.

2. **Changed** expected page count in
   `testPrintOperationRunsHeadlessAndProducesAllPages` from `2` to `3`
   → `swift test --filter DocumentPrintingTests`:
   ```
   error: -[...testPrintOperationRunsHeadlessAndProducesAllPages] :
   XCTAssertEqual failed: ("Optional(2)") is not equal to ("Optional(3)")
   Executed 4 tests, with 1 failure
   ```
   **RED**, as expected. Restored `2`, re-ran → 4/4 **GREEN**.

3. Full `swift test` after both restores: 170 pass / 7 skip / 0 failures
   (pasted above) — no regression vs. the 166/7 baseline.

## Notes for tester

**What's already verified by automated test (don't re-check by hand):**
- `makePrintOperation()` returns `nil` with no document.
- `jobTitle` is set from `store.title`; `showsPrintPanel` defaults `true`;
  `printInfo` is a fresh instance, not `NSPrintInfo.shared`.
- Full headless print: `two-page.pdf` fixture → configured operation with
  `jobDisposition = .save` + `jobSavingURL` + panels off → `op.run()` returns
  `true` → output file re-opens with `pageCount == 2`. This is a real,
  currently-passing test on this machine (not just the plan's probe script).
- `PDFAnnotation(...forType: .highlight/.ink...)` has `shouldPrint == true` by
  default (pinned so an OS/PDFKit default change goes red before a user
  notices annotations missing from print output).

**What still needs a human driving the actual GUI (plan step 5, not attempted
here — deliberately out of coder scope):**
1. Open `Tests/Fixtures/source/annotated-highlight-ink.pdf` → ⌘P → confirm
   the print panel opens as a **sheet** on the document window; in the panel,
   PDF → "Save as PDF" → confirm all pages present and highlight + ink marks
   show up in the output.
2. In the same panel, restrict the page range (e.g. "From 2 to 2") → Save as
   PDF → confirm the output has exactly that one page.
3. Generate `rotated.pdf` via `script/generate_pdf_fixtures.sh`, open it,
   ⌘P → Save as PDF → confirm text orientation is correct and nothing is
   clipped (this is the `autoRotate: true` choice from the plan — the plan
   flags this as unverified beyond the config, needs a real render check).
4. With no document open: confirm "In…" is disabled in the File menu and ⌘P
   does nothing.
5. Write results into a new dated file under `qa-report/` (style:
   `qa-report/azpdf-macos-2026-07-20.md`) with PASS/FAIL for each of the 4
   items above.

No new test fixtures were needed — everything used the existing
`Tests/Fixtures/source/two-page.pdf` (automated) and
`Tests/Fixtures/source/annotated-highlight-ink.pdf` / generated `rotated.pdf`
(manual, per plan).

## Notes for reviewer

- No dead code spotted in the touched files. `DocumentStore+Printing.swift`
  is new and minimal (builder + runner, per plan — no extra abstraction).
- `printDocument()`'s `NSApp.keyWindow` branch is not covered by an automated
  test (can't reliably have a key window in a headless `swift test` run);
  this is inherent to driving real AppKit panels and is exactly the kind of
  thing plan step 5 exists to catch. `makePrintOperation()` — the actual
  logic — is fully covered.
- Followed the plan's exact API choice: builder off `PDFDocument`, not
  `PDFView`, matching the store's existing `document: PDFDocument` field and
  the `DocumentStore+FileIO.swift` pattern (store methods drive `NSSavePanel`
  etc. directly, no plumbing through `PlacementPDFView`/`readerAction`).
- Scope holds: did not touch `Adapters/`, `Core/`, `Shell/`, `Package.swift`,
  or the `.newItem` command group (2f's "New Window" bug is untouched, as
  instructed). Did not add `shouldPrint = true` at annotation-creation sites
  — the pin test passed, so per plan that 5-line fallback isn't needed.
