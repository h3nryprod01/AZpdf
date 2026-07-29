# Code summary — Lát cắt 1e: Ma trận operation-conformance 18 case × 2 engine

## Files changed
- `Core/PDFEngineOperationConformance.swift` — new. Foundation-only harness: for every
  `DocumentOperation` case, loads a fresh document from fixture bytes, runs `apply`, then
  classifies `supported`/`unsupported`/`failed` from a read-back postcondition (not from
  whether `apply` threw). Public Codable report types (`PDFOperationConformanceResult`,
  `PDFOperationConformanceReport`).
- `Tests/Fixtures/source/two-page.pdf` — new binary fixture (1166 bytes), committed bytes, not
  generated at test time. 2 pages, page 0 text contains `AZPDF-P1`, page 1 contains `AZPDF-P2`,
  MediaBox 595×842, rotation 0. Built once via `mutool create` from two throwaway content-stream
  `.txt` files (not committed — same convention as the existing `annotated-highlight-ink.pdf`,
  which also has no committed generator script).
- `Tests/AZpdfTests/EngineOperationMatrixTests.swift` — new. Pins the PDFKit baseline: fixture
  loads correctly, and the 17-case matrix result.
- `Tests/AZpdfMuPDFTests/MuPDFOperationMatrixTests.swift` — new. Pins the MuPDF baseline, reusing
  the mutool-detection pattern from `MuPDFAnnotationKindTests.swift` (candidate paths + `MUTOOL_BIN`
  env var, `XCTSkip` if absent) plus an added version gate (`XCTSkip` if `mutool -v` < 1.24, the
  same threshold `script/qa_linux_smoke.sh` uses for the same reason — annotation JS needs ES modules).
- `Tests/AZpdfCoreTests/OperationConformanceLyingEngineTests.swift` — new. In-memory stub engine
  whose `apply` always returns success without mutating anything; proves the harness still reports
  `.failed` for `rotate` (i.e., it isn't fooled by a non-throwing no-op).
- `qa-report/engine-operation-matrix-2026-07.md` — new. The 17×2 result table + 3 conclusion lines
  for the engine-direction decision, per the plan's requested output.

**Package.swift**: not touched. `AZpdfCoreTests` already existed as a target (confirmed by reading
the file before starting), so the "add test target if needed" contingency in the task brief did
not apply.

## Steps completed
- [x] 1. Fixture 2 trang ✓ — `mutool create` from two content-stream files, verified via `mutool pages`/`mutool draw -F txt` directly, then re-verified through `PDFKitDocumentEngine` in step 3 (`testPDFKitLoadsTwoPageFixture`).
- [x] 2. Harness trong Core ✓ — `swift build --target AZpdfCore` clean; `script/audit_portable_core.sh` exit 0.
- [x] 3. Ghim baseline PDFKit ✓ — `swift test --filter EngineOperationMatrixTests` → 0 failures.
- [x] 4. Ghim baseline MuPDF ✓ — `swift test --filter MuPDFOperationMatrixTests` → 0 failures (ran for real against `mutool 1.28.0`, not skipped).
- [x] 5. Mutation check ✓ — automated lying-engine test passes, plus a manual mutate/restore cycle on the harness itself (both logged below).
- [x] 6. Bảng số liệu ✓ — `qa-report/engine-operation-matrix-2026-07.md` written; full `swift test` → 165 executed, 7 skipped, 0 failures.

## Verify output (real, not paraphrased)

**Step 2** — `swift build --target AZpdfCore`:
```
Build of target: 'AZpdfCore' complete! (2.30s)
```
`script/audit_portable_core.sh`:
```
Portable-core audit passed: Core remains Foundation-only.
exit=0
```

**Step 3** — `swift test --filter EngineOperationMatrixTests`:
```
Test Case '-[AZpdfTests.EngineOperationMatrixTests testPDFKitLoadsTwoPageFixture]' passed (0.059 seconds).
Test Case '-[AZpdfTests.EngineOperationMatrixTests testPDFKitOperationMatrixBaseline]' passed (0.003 seconds).
Executed 2 tests, with 0 failures (0 unexpected) in 0.062 (0.063) seconds
```

**Step 4** — `swift test --filter MuPDFOperationMatrixTests`:
```
Test Case '-[AZpdfMuPDFTests.MuPDFOperationMatrixTests testMuPDFOperationMatrixBaseline]' passed (0.737 seconds).
Executed 1 test, with 0 failures (0 unexpected) in 0.737 (0.737) seconds
```
(Ran against the real, installed `mutool version 1.28.0` at `/opt/homebrew/bin/mutool` — not skipped.)

**Step 5** — automated lying-engine test:
```
Test Case '-[AZpdfCoreTests.OperationConformanceLyingEngineTests testHarnessCatchesEngineThatClaimsSuccessWithoutChangingRotation]' passed (0.002 seconds).
```

**Step 5** — manual mutation check on the harness (per repo mutation-testing discipline; not a
committed change, done and reverted in this session):
1. Edited `Core/PDFEngineOperationConformance.swift`, changed the rotate postcondition from
   `guard rotation == 90 else` to `guard rotation == 91 else`.
2. Ran `swift test --filter EngineOperationMatrixTests` → **RED**:
   ```
   XCTAssertEqual failed: ("["duplicate", "delete", "movePages", "insertDocument", "setMetadata"]")
   is not equal to ("["rotate", "delete", "movePages", "setMetadata", "insertDocument", "duplicate"]")
   ...PDFOperationConformanceResult(operation: "rotate", status: .failed,
      detail: "Kỳ vọng rotation trang 0 = 90, nhận 90.")...
   XCTAssertTrue failed - Không case nào được phép .failed: ["rotate"]
   Executed 2 tests, with 2 failures (0 unexpected) in 0.317 (0.318) seconds
   ```
3. Reverted the line back to `guard rotation == 90 else`.
4. Ran `swift test --filter EngineOperationMatrixTests` again → **GREEN**:
   ```
   Test Case '-[AZpdfTests.EngineOperationMatrixTests testPDFKitOperationMatrixBaseline]' passed (0.002 seconds).
   Executed 2 tests, with 0 failures (0 unexpected) in 0.060 (0.060) seconds
   ```
   Confirmed via `grep` that no `rotation == 9`-adjacent artifact or `MUTATION-CHECK` marker was
   left in the file after revert.

**Step 6** — full suite, `swift test`:
```
Executed 165 tests, with 7 tests skipped and 0 failures (0 unexpected) in 2.712 (2.727) seconds
```
Baseline (measured by temporarily moving all 6 new files out and re-running, then restoring them —
verified this exact machine's pre-existing state rather than trusting the number in the task brief):
```
Executed 161 tests, with 7 tests skipped and 0 failures (0 unexpected) in 1.956 (1.968) seconds
```
165 − 161 = 4, exactly the 4 new test methods added (2 in `EngineOperationMatrixTests`, 1 in
`MuPDFOperationMatrixTests`, 1 in `OperationConformanceLyingEngineTests`). Skip count unchanged at 7,
failures 0 in both runs.

**Note on the "161 pass / 7 skip" baseline in the task brief**: XCTest's own summary line reads
"Executed N tests, with S skipped and F failures" — N is the *total* attempted, not the passed
count. The brief's "161 pass" appears to be that literal line paraphrased loosely (161 total, of
which 7 skipped ⇒ 154 actually passed). Measured directly on this machine, pre-change state is
"Executed 161 tests, with 7 tests skipped and 0 failures" — i.e. the "161" matches the total, not
the pass count. Flagging this because the constraint said accuracy matters more than a tidy number;
the important invariants (0 new failures, skip count held at 7) both check out regardless of which
reading is correct.

## Bảng số liệu 18×2 đo được — thực tế là 17×2

**`DocumentOperation` có 17 case, không phải 18.** Đếm trực tiếp
(`grep -c '^    case ' Core/DocumentOperation.swift` = 17, danh sách tên khớp with the harness's
17 `OperationCase` entries) trước khi viết harness, để không bịa ra case thứ 18. Plan's "18" is
carried into the task title too; treating it as the plan's own approximation rather than silently
matching it — the measured count is what's asserted in `EngineOperationMatrixTests`
(`XCTAssertEqual(report.results.count, 17)`), and `qa-report/engine-operation-matrix-2026-07.md`
calls the discrepancy out explicitly for whoever reads the table next.

| # | Operation | PDFKit | MuPDF |
|---|---|---|---|
| 1 | rotate | supported | unsupported |
| 2 | duplicate | supported | unsupported |
| 3 | delete | supported | unsupported |
| 4 | movePages | supported | unsupported |
| 5 | insertPages | unsupported | unsupported |
| 6 | addAnnotation | unsupported | unsupported |
| 7 | redact | unsupported | unsupported |
| 8 | insertDocument | supported | unsupported |
| 9 | setMetadata | supported | unsupported |
| 10 | upsertAnnotation | unsupported | supported |
| 11 | upsertImageAnnotation | unsupported | supported |
| 12 | removeAnnotation | unsupported | supported |
| 13 | flattenAnnotations | unsupported | unsupported |
| 14 | setFormValue | unsupported (fixture has no form field to match — see below) | unsupported |
| 15 | setOutline | unsupported | unsupported |
| 16 | upsertEmbeddedFile | unsupported | unsupported |
| 17 | removeEmbeddedFile | unsupported | unsupported |

Totals: **PDFKit 6 supported / 11 unsupported / 0 failed. MuPDF 3 supported / 14 unsupported / 0
failed.** Zero overlap — no operation is `supported` on both engines today, empirically confirming
the plan's "portable core mỏng về nội dung" claim rather than just reading it off the adapter code.
Zero `.failed` on either engine (the "engine nói dối" gate from the plan's "Đo bằng gì" section holds).

Full per-case detail (including the exact `detail` string returned by the harness for every row)
is in `qa-report/engine-operation-matrix-2026-07.md`.

### Where reality differed from the plan's prediction
- **Case count**: plan said 18, actual is 17 (see above). All "6/18" and "3/18" framing in the
  plan should be read as "6/17" and "3/17" going forward.
- **`setFormValue` for PDFKit**: the plan already anticipated this exactly right — the code path
  exists in `PDFKitDocumentEngine.apply`, but on this fixture (no form field) it throws
  `operationNotSupported` because nothing matches `fieldID`, so the harness classifies it
  `unsupported`, indistinguishable by error type alone from a truly-missing code path. No surprise
  here; just confirming the plan's own caveat measured true.
- **Everything else matched the plan's prediction exactly**: PDFKit's supported set
  {rotate, duplicate, delete, movePages, insertDocument, setMetadata} and MuPDF's supported set
  {upsertAnnotation, upsertImageAnnotation, removeAnnotation} were both hit precisely, with 0
  failures on either side. No assertion was loosened to make this happen — the numbers came out
  clean on the first real run against both engines (including the real `mutool` binary, not a mock).

## Notes for tester
- MuPDF tests in this slice need a real `mutool` ≥ 1.24 on PATH (or `MUTOOL_BIN` env var) to
  actually run; otherwise `MuPDFOperationMatrixTests` skips (not fails) via `XCTSkip`, same pattern
  as `MuPDFAnnotationKindTests`. This machine has `mutool 1.28.0` at `/opt/homebrew/bin/mutool`, so
  it ran for real, not skipped — the numbers in the qa-report are from an actual mutool run.
- `Tests/Fixtures/source/two-page.pdf` is a new committed binary fixture; if you regenerate fixtures
  for any reason, page 0 must keep containing the literal string `AZPDF-P1` and page 1 `AZPDF-P2` —
  several postconditions (`redact`, `movePages`) depend on exact string matching, not just page count.
  `two-page.pdf` is reused as the `insertDocument` auxiliary too (same bytes, both test files).
  Regenerate with: `mutool create -o two-page.pdf p1.txt p2.txt` where each `.txt` is a
  `%%MediaBox 0 0 595 842` content stream with a `Tj` for the marker string (see the git history of
  this file for the exact throwaway inputs used, or `script/generate_pdf_fixtures.sh` for the
  existing content-stream DSL convention).
- The 1×1 PNG embedded as a base64 literal in both `EngineOperationMatrixTests.swift` and
  `MuPDFOperationMatrixTests.swift` (`iVBORw0KGgo...`) was generated fresh via Python's stdlib
  `zlib`/`struct` (no third-party dependency) and verified with `sips` and `file` to be a real,
  valid 1×1 RGB PNG — not a remembered/guessed base64 string. It round-trips through MuPDF's own
  `mupdf.Image()` loader in the `upsertImageAnnotation` case (confirmed: that case reports
  `supported` on the real mutool run).
- `PDFEngineOperationConformance.run` is deterministic and has no timing assertions — it answers
  correctness only. The plan's 1d benchmark item (round-trip latency of MuPDF subprocess calls) is
  explicitly out of scope here; the qa-report's third conclusion line flags this so 1d doesn't get
  skipped.

## Notes for reviewer
- `flattenAnnotations`'s postcondition (`annotations(onPage:0).isEmpty` after apply) is vacuously
  true on this fixture today, since the fixture starts with zero annotations and neither engine
  implements `flattenAnnotations` yet (both throw `operationNotSupported` before the postcondition
  is ever evaluated). I considered adding a `prepare` step (upsert an annotation first, mirroring
  `removeAnnotation`) to make it non-trivial, but the plan's own postcondition wording for this case
  doesn't call for a setup step (unlike `removeAnnotation`, where it explicitly says "upsert trước
  rồi remove"), so I implemented exactly what the plan specified rather than silently strengthening
  it. Flagging in case a reviewer wants it tightened before an engine actually implements flatten in 2g.
  Costs nothing today either way — both engines land on `unsupported` regardless of which check is used.
- `setFormValue`/`setOutline`/`upsertEmbeddedFile`/`removeEmbeddedFile` use a deliberately weak
  "round trip survives" postcondition (`// ponytail:` comment in the harness explains why), per the
  plan's own explicit instruction. None of these four cases exercises that verify closure today
  (both engines throw `operationNotSupported` first), so its weakness is currently inert — it only
  becomes load-bearing once 2g wires a real implementation, at which point it should be tightened
  using a fixture that actually has a matching form field / outline / attachment.
- No dead code spotted in the files touched. No adjacent code was refactored — every changed line
  is a new file or, in `plan.md`, a checkbox tick.
