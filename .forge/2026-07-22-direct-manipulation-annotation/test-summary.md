# Test summary — Direct-manipulation annotation editing (macOS AZpdf)

## Test framework
XCTest (`swift test --package-path <dir>`), matching every existing suite under `Tests/AZpdfTests`.

## Scope of this pass
The implementation (incl. the overlay-`NSView` bug fix) was already GUI-verified by the
orchestrator. This pass only strengthens **automated** coverage of `Models/AnnotationHandles.swift`
and the `DocumentStore` resize/undo + ink render-verify tests already added by the coder — no
production code changes were kept (see "Mutation testing" below for the temporary, reverted
edits used to validate the tests themselves). No files under `Adapters/`, `Core/`, `Package.swift`,
or `Shell/` were touched.

## Files added
None (no new test files — the existing two files already had the right suites; this pass
strengthened/added test *functions* in place).

## Files edited
- `Tests/AZpdfTests/AnnotationHandlesTests.swift` — 11 → 14 tests:
  - Strengthened `testResizedBoundsCornerLockedPreservesRatioWithEvenScale` with exact
    width/height assertions (120×80) pinned to the "pick the larger of the two required
    scales" (`max(...)`) semantics — a ratio-only check can't distinguish `max` from `min`
    (both preserve the aspect ratio).
  - Added `testResizedBoundsLeftEdgeChangesOnlyWidthAnchoredOnRightEdge` and
    `testResizedBoundsBottomEdgeChangesOnlyHeightAnchoredOnTopEdge` — the original suite only
    exercised `.right` and `.top`; `.left`/`.bottom` share the same helper functions but must
    anchor the *opposite* edge, so a copy-paste min/max mixup between the two would previously
    have gone uncaught.
  - Added `testResizedBoundsGuardsDivideByZeroWhenOriginalHeightIsZero` (only the `width == 0`
    case existed before; the guard is `original.width > 0, original.height > 0`, so both
    branches needed their own case).
- `Tests/AZpdfTests/DocumentStoreTests.swift` — 39 → 40 tests:
  - Added `testResizeSelectedAnnotationEnforcesMinimumSizeFloorIndependentlyOfHandles` — the
    24×24 floor is enforced *twice* (once in `AnnotationHandles.resizedBounds`, again in
    `resizeSelectedAnnotation` itself as defense-in-depth against a caller bypassing the
    handles), but no existing test ever called `resizeSelectedAnnotation` with a sub-24 rect,
    so the store's own `max(24, …)` line had zero coverage.
  - Rewrote `testResizedInkAnnotationStillRendersAfterRoundTrip` (same test, same
    round-trip-through-`dataRepresentation()` + rasterize-and-scan technique) so it can no
    longer pass on a no-op resize — see "Mutation testing" below for why the original version
    could.

## Mutation testing (why these specific assertions were added)
Per instructions, verified each strengthened/added assertion is actually load-bearing by
introducing a real, temporary source mutation, confirming the test failed, then reverting the
source to its exact original text (byte-diff re-read after every revert) and confirming the
suite was green again. All mutations below were reverted; no production file has a net diff.

1. **`AnnotationHandles.resizedCorner`'s aspect-lock `scale = max(...)`.** Flipped to `min(...)`.
   Result: **all 11 original tests still passed** — the pre-existing "ratio preserved" assertion
   cannot tell `max` from `min` apart (both preserve the ratio; they only differ in which axis
   drives the resulting size). Added exact-value assertions (120×80, not just "some ratio-1.5
   size") that fail correctly under this mutation (`75.0` vs expected `120.0`), then reverted.
2. **`.left`/`.bottom` edge anchors.** Temporarily set `.left`'s anchor to `original.minX`
   (matching `.right`'s, instead of `original.maxX`) — new `testResizedBoundsLeftEdgeChangesOnlyWidthAnchoredOnRightEdge`
   failed correctly (`104.0` vs `160.0` for the anchored edge). Reverted, then repeated for
   `.bottom` (set its anchor to `original.minY`, matching `.top`) — new
   `testResizedBoundsBottomEdgeChangesOnlyHeightAnchoredOnTopEdge` failed correctly. Reverted.
3. **`DocumentStore.resizeSelectedAnnotation`'s `max(24, …)` floor.** Removed it (raw
   `newBounds.width`/`.height`). New floor test failed correctly (`5.0×3.0` vs expected
   `24.0×24.0`). Reverted.
4. **Same method, made a full no-op** (commented out the `annotation.bounds =` assignment
   entirely, kept `modificationDate`/`isModified`/`documentRevision` side effects). Result:
   - `testResizeSelectedAnnotationCommitsAndUndoRestores` correctly failed (proves that test is
     legitimately resize-sensitive).
   - **`testResizedInkAnnotationStillRendersAfterRoundTrip` (the coder's original version)
     still PASSED.** Root cause: the original test resized the annotation from `(20,20,80,40)`
     to `(20,20,160,80)` — same origin, only larger — so the pixel-scan region for "ink still
     visible" was a strict superset of where the *original, unmoved* ink already was. A
     completely broken (no-op) resize would leave the ink exactly where it started, which the
     scan region still covered, so the assertion passed for the wrong reason. This is exactly
     the "confirm the render test actually asserts ink survives a resize, not a no-op" concern
     called out in the task.
   - **Fix:** changed the resize target from a same-origin enlargement to a **disjoint**
     move-and-resize (`(10,10,30,30)` → `(10,90,60,40)`, a 50pt gap on a 100×140 synthetic
     page) and added a second assertion that the *old* bounds region now contains **no** red
     pixel. Re-ran the same no-op mutation: **both assertions now fail** ("should still render
     inside its new bounds" and "should no longer render at the pre-resize bounds"). Reverted
     the mutation; the strengthened test passes on the real (correct) implementation.

## Run result
Full suite, `swift test --package-path /Users/nguyenphucuong/Documents/Codex/2026-07-16/azpdf-fix`:

```
Test Suite 'AZpdfPackageTests.xctest' passed at 2026-07-22 23:28:02.170.
	 Executed 139 tests, with 7 tests skipped and 0 failures (0 unexpected) in 3.653 (3.667) seconds
Test Suite 'All tests' passed at 2026-07-22 23:28:02.171.
	 Executed 139 tests, with 7 tests skipped and 0 failures (0 unexpected) in 3.653 (3.668) seconds
```

Sub-suite counts of interest:
- `AnnotationHandlesTests`: 14/14 passed (was 11).
- `DocumentStoreTests`: 40 executed, 1 skipped (pre-existing, external veraPDF integration), 0
  failures (was 39/1 skip).

The 7 skips are all pre-existing (external fixtures / `AZPDF_RUN_EXTERNAL_INTEGRATION`), not
introduced or affected by this pass — identical skip set to the coder's baseline. `swift build`
is clean (only the pre-existing unrelated "10 unhandled resource files" warning under
`Packaging/flatpak/`).

## Coverage
No `.profdata`/`llvm-cov` tooling is wired into this package (`swift test --enable-code-coverage`
was not attempted since no coverage-report step exists in this project's scripts/CI, and adding
one would be out of scope for a test-only pass). Coverage assessed by direct inspection instead:

- `Models/AnnotationHandles.swift` — every branch is now exercised at least once, and every
  branch that carries real risk (aspect-lock scale direction, all 4 edge anchors, both
  divide-by-zero guards, min-size clamp, cropBox clamp, hit-test priority) has a
  mutation-verified test (see above). This is effectively 100% line/branch coverage of the
  pure-math struct.
- `resizeSelectedAnnotation`/`beginAnnotationResize` (`Stores/DocumentStore+Annotations.swift`)
  — bounds-commit, `isModified`, undo-restore, and the store's own 24×24 floor are all directly
  and independently asserted.
- `testResizedInkAnnotationStillRendersAfterRoundTrip` — now genuinely exercises the "bug F"
  risk path end to end (mutate → serialize → reload → rasterize → pixel-scan) and is
  mutation-verified to fail on a broken resize, not just "ink renders somewhere."

## Anything skipped
- **No code-coverage tool run** (see above) — reasoned about coverage qualitatively via mutation
  testing instead, which is a stronger signal than a line-coverage percentage for this kind of
  pure-math/state-mutation code anyway.
- **GUI/PlacementPDFView interaction** (mouse hit-testing → handle drag → live bounds mutation →
  popover show/hide, the overlay-`NSView` compositing fix) intentionally left untested
  headlessly, per the task's framing — already human-verified by the orchestrator, and AppKit
  mouse-event/NSPopover/compositing behavior isn't practically unit-testable without a real
  window server session. `AnnotationHandles` (the pure maths this view calls into) has full
  coverage instead, which is where a regression would actually be catchable in CI.
- **No new failure/edge-case test for the `guard let annotation = selectedAnnotation else
  { return }` no-selection paths** in `resizeSelectedAnnotation`/`beginAnnotationResize` —
  consistent with every other guarded store method in this file (e.g. `moveSelectedAnnotation`
  has no such test either); a bare early-return has no interesting failure mode to assert on
  beyond "doesn't crash," which XCTest already guarantees by simply not throwing.
