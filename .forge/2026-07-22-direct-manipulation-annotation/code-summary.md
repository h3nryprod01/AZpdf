# Code summary — Direct-manipulation annotation editing (macOS AZpdf)

## Bug fix — 2026-07-22: selection frame + handles not rendering

**Symptom (as reported):** clicking an annotation correctly shows the caret
popover (with the relocated a11y move controls), but the accent selection
frame and resize-handle squares never appear on screen.

### Root cause — diagnosed, not guessed

Both hypotheses from the bug report were checked empirically with a small
headless `PDFView` probe (built + run outside the package via `swift
<script>.swift`, using `NSApplication.shared` + an offscreen `NSWindow` +
`cacheDisplay(in:to:)`/`bitmapImageRepForCachingDisplay`, no interactive
session needed):

- **Hypothesis 2 (bad `convert(_:from:)` math) — ruled out.** For a
  `500×700` view showing a `400×600` page, `pdfView.convert(annotation.bounds,
  from: page)` returned `(29.4, 6.4, 98.0, 49.0)` — a correct, in-bounds,
  non-degenerate view-space rect every time. The coordinate math was never
  the problem.
- **Hypothesis 1 (PDFKit re-tiles/re-renders asynchronously, painting over a
  static overlay) — confirmed structurally.** Dumping the live subview tree
  of a real `PDFView` shows PDFKit renders actual page pixels through a
  `PDFPageView`/`PDFPageLayer` nested three levels deep inside its own
  `PDFScrollView` — a **full-bounds subview PDFKit adds to the `PDFView`
  itself at init time**:
  `PDFView → PDFScrollView → PDFClipView → PDFDocumentView → PDFPageView
  (layer: PDFPageLayer)`.
  Because `PDFScrollView` is a subview covering the view's entire bounds,
  ordinary AppKit z-order means it (and its nested, separately re-rendering
  `PDFPageLayer`) always composites *above* anything drawn directly in
  `PlacementPDFView.draw(_:)` — the frame was being drawn correctly every
  time, then immediately painted over. A confirmatory probe verified the fix
  direction too: a plain `NSView` appended to `pdfView.subviews` *after*
  `PDFScrollView` reliably composites on top in a synchronous snapshot
  (white page background → visibly reddened once a solid-red overlay view
  was added). The continuously-redrawn OCR drag rect only ever "worked"
  because it re-wins that same paint race on every `mouseDragged` tick; a
  one-shot static frame draw always loses it once PDFKit's page layer
  re-composites.

### Fix

Added a dedicated, transparent, click-through `AnnotationSelectionOverlayView
: NSView` (bottom of `Views/PDFReaderView.swift`), added as the **last**
subview of `PlacementPDFView` (i.e. after PDFKit's own `PDFScrollView`), so
it always composites on top:
- `hitTest(_:)` always returns `nil` — every mouse event still reaches
  `PlacementPDFView` completely unchanged; all hit-testing, resize, and
  popover logic stays exactly where it was (per the constraint: draw-only
  change).
- `draw(_:)` calls back into a new tiny `PlacementPDFView.drawSelectionOverlayContent()`
  wrapper, which guards `selectedAnnotation`/`selectedPage` and then calls
  the **existing, untouched** `drawSelectionFrame(for:on:)` — same
  `convert(annotation.bounds, from: page)` math, same `AnnotationHandles`
  usage, zero changes to any maths or drawing code, only *where* it's
  invoked from.
- `PlacementPDFView.draw(_:)` no longer draws the selection frame directly
  (that block was removed); the OCR marquee code in `draw(_:)` is untouched.
- A new `override func viewWillDraw()` on `PlacementPDFView` keeps the
  overlay's frame synced to `bounds` and marks it `needsDisplay = true`
  every time `PlacementPDFView` itself is about to redraw. This was also
  empirically verified (headless probe) rather than assumed: `viewWillDraw()`
  fired reliably on select/move/resize (which already call `self.needsDisplay
  = true`) **and** on scroll and `go(to:)` page navigation — including one
  case where a scroll+display pass invoked `viewWillDraw()` but *not*
  `draw(_:)`, which is exactly why the hook lives in `viewWillDraw()` and not
  in `draw(_:)`.

Net effect: the selection-frame/handle *maths and drawing code* are 100%
unchanged (`AnnotationHandles`, `drawSelectionFrame`); only where that
drawing physically happens moved from "inline in `PlacementPDFView.draw(_:)`"
to "a dedicated topmost subview's own `draw(_:)`, kept in sync via
`viewWillDraw()`".

### Files changed (this pass)
- `Views/PDFReaderView.swift` — added `selectionOverlay` (lazy, self-adding
  subview), `viewWillDraw()` override, `drawSelectionOverlayContent()`
  wrapper, and the new `AnnotationSelectionOverlayView` class; removed the
  inline selection-frame draw call from `PlacementPDFView.draw(_:)`.
  No other file touched.

### Verification
- `swift build --package-path <dir>` — exit 0, clean (only the pre-existing
  unrelated "unhandled resource files" warning).
- `swift test --package-path <dir>` — 135 tests, 7 pre-existing skips
  (external fixtures), **0 failures** — identical counts to the pre-fix
  baseline, no regressions.
- `./script/build_and_run.sh --bundle` — exit 0, `dist/AZpdf.app` assembled.
- GUI verification (does the frame/handles actually paint, aspect-lock via
  Shift, popover position, drag-resize) still needs the orchestrator/tester —
  no interactive display session available here, consistent with the
  original pass.

### Notes for reviewer (this pass)
- The diagnostic scripts used to confirm the root cause were throwaway,
  written and run from the scratchpad directory (outside the repo) — nothing
  diagnostic was left in the codebase.
- Did not add `NSClipView.boundsDidChangeNotification` observation or any
  other PDFKit-notification plumbing for scroll/zoom: the `viewWillDraw()`
  piggyback was empirically confirmed sufficient (see above), so the extra
  notification bookkeeping (register/deinit/find-the-clip-view) would have
  been unrequested complexity for a case already covered. If a future bug
  report shows the frame drifting out of sync specifically *during* a live
  scroll gesture (as opposed to "not appearing" — a different symptom), that
  would be the next thing to add, not something needed now.
- `selectionOverlay.setAccessibilityElement(false)` was added so the new
  decorative view doesn't show up as an empty stop in VoiceOver navigation
  over the PDF content — small, in-style with this file's existing a11y
  discipline (`setAccessibilityLabel`/`setAccessibilityHelp` on the same
  view), not itemized by any step but a direct, low-risk consequence of
  adding a new subview.

---

## Files changed
- `Models/AnnotationHandles.swift` (new) — pure `CoreGraphics`-only struct: handle-rect geometry, hit-testing (`handle` > `body` > `none`), and the clamped resize maths (corner aspect-lock/free, edge, min-size, cropBox intersection).
- `Tests/AZpdfTests/AnnotationHandlesTests.swift` (new) — 11 unit tests covering handle centring, hit-test priority, corner free/locked resize, horizontal/vertical edge resize, min-size clamp, cropBox clamp, and the zero-width divide-by-zero guard.
- `Stores/DocumentStore+Annotations.swift` — added `beginAnnotationResize()` (snapshots undo, mirrors `beginAnnotationMove`) and `resizeSelectedAnnotation(to:)` (commits bounds with a `max(24,…)` floor, no `registerUndoStep`); removed the now-orphaned `updateSelectedImageSize()`.
- `Models/PDFAnnotation+AZpdf.swift` — added `isAZpdfResizable` (`isAZpdfFreeText || isAZpdfInk || isAZpdfImage`) used by the popover and the view's handle drawing/hit-testing.
- `Views/AnnotationEditPopover.swift` (new) — SwiftUI popover content: the four type-specific edit sections transplanted from the Inspector onto the same store bindings/methods, plus the relocated move-arrow accessibility controls; "Xóa" calls `onDelete` (never the store directly).
- `Views/PDFReaderView.swift` — `PlacementPDFView` gained on-object selection state (`selectedAnnotation`/`selectedPage`), resize state (`activeHandle`/`resizeStartBounds`), a lazy `NSPopover`, handle hit-testing in `mouseDown`, a resize branch in `mouseDragged`, resize-commit + popover-present in `mouseUp`, frame/handle drawing in `draw()`, Esc-to-deselect in `keyDown`, and a single `deleteSelected()` path used by both the Delete key and the popover. `PDFReaderView` wires the new closures and dropped the now-unused `onAnnotationSelected` param.
- `Views/DocumentInspectorView.swift` — removed the four type-specific edit sections and their two private helpers (`deleteSelectedButton`, `annotationPositionControls`); kept page/document/form info and the "Chú thích — N" list.
- `Views/ContentView.swift` — removed both Inspector auto-open sites (the `PDFReaderView` selection closure and the `.onChange(of: store.annotationSelectionID)` handler).
- `Tests/AZpdfTests/DocumentStoreTests.swift` — added `testResizeSelectedAnnotationCommitsAndUndoRestores` and `testResizedInkAnnotationStillRendersAfterRoundTrip` (the "bug F" ink render-verify net).

## Steps completed
- [x] 1. `Models/AnnotationHandles.swift` ✓
- [x] 1b. `Tests/AZpdfTests/AnnotationHandlesTests.swift` ✓ 11/11 pass
- [x] 2. `DocumentStore+Annotations.swift` resize methods + store test ✓
- [x] 3. `Views/AnnotationEditPopover.swift` ✓
- [x] 4. `PlacementPDFView` resize/frame/popover wiring ✓ (build verified; manual GUI check deferred to tester — no interactive macOS session available here)
- [x] 5. Inspector trim + auto-open removal ✓
- [x] 6. Ink render-verify test ✓
- [x] 7. Full verification (build, test, bundle) ✓ all exit 0

All 7 (+1b) steps are checked. No step was skipped or left undone.

## Decisions applied (per plan's locked section)
1. Handle policy: free-text gets 8 handles (corners + edges), image/ink get 4 corner handles only — enforced via `AnnotationHandles.handleRects(includeEdges:)` gated on `isAZpdfFreeText`, in both `drawSelectionFrame` and `activeResizeHandle`.
2. Inspector auto-open removed in both places (`ContentView`'s `PDFReaderView` selection closure and the `annotationSelectionID` `.onChange`).
3. A11Y: `annotationPositionControls` was not deleted — its content was relocated verbatim into `AnnotationEditPopover.positionControls` for all four annotation types (free-text/note/image/ink), so keyboard/VoiceOver move survives the redesign. `moveSelectedAnnotation` itself (in `DocumentStore+Annotations.swift`) was untouched.

## Notes for tester
- Manual GUI verification (frame draw, handle drag-resize, aspect lock via Shift, caret popover position/dismiss-on-drag) was not exercised interactively — only `swift build` succeeded. Worth walking through: select a free-text box (8 handles incl. edges), an image/ink (4 corner handles only, aspect-locked by default, Shift frees it; free-text is free by default, Shift locks it), and a note (frame only, no handles).
- `testResizedInkAnnotationStillRendersAfterRoundTrip` (new, in `DocumentStoreTests.swift`) uses a saturated pure-red ink color + an explicit `PDFBorder(lineWidth: 10)` and scans the *entire* resized-bounds region of a rasterized `page.thumbnail` for a red pixel — deliberately avoiding a brightness/background heuristic since the synthetic test page's composited backdrop isn't guaranteed. If this test ever needs debugging, note it doesn't assert exact stroke position, only "still visible somewhere inside the new `/Rect`" (i.e., not clipped/lost) — that is what "bug F" was about.
- Esc only deselects when the view already has an on-object selection; with nothing selected it falls through to `super.keyDown` unchanged (preserves prior no-op behavior, avoids a stray system beep).
- Right-click-to-select (`menu(for:)`) was intentionally left untouched (not in Step 4's scope) — it still calls `onSelectAnnotation?` but does not set the view's local `selectedAnnotation`/`selectedPage`, so it won't draw an on-object frame for the right-clicked annotation. This is a pre-existing-style gap, not a regression (see Notes for reviewer).

## Notes for reviewer
- **Cross-step compile coupling (Steps 2–5):** Step 2 removes `updateSelectedImageSize()`; its only caller lived in `DocumentInspectorView.swift`'s image section, which Step 5 deletes. Because `swift test --filter X` still compiles the whole target, Step 2's own verify command could not go green in isolation — it only passed once Steps 3–5 landed. I implemented Steps 2→3→4→5 in sequence without an intermediate broken-build commit (coder makes no commits anyway), then ran every step's verify command for real once the full group compiled. Flagging this since it's a real plan-sequencing artifact, not a shortcut — a future plan could avoid it by doing the Inspector deletion in the same step as the store method removal, or by temporarily stubbing the caller.
- **Store-side stale-selection gap (pre-existing, not fixed):** `DocumentStore.undo()`/`redo()` replace the whole `PDFDocument` object graph but never clear `store.selectedAnnotation`, so after an Undo the store can hold a `PDFAnnotation` reference detached from the current document (this predates this change — the old Inspector sections had the same latent gap, just less visibly). I *did* defend the new on-object frame against this (see below) since it's a new persistent visual element this feature introduces, but I did not touch `DocumentStore.swift` to fix the store's own field, since that file is outside every step's stated scope and outside the design spec's "MAY touch" list.
- **New defensive addition (in scope, not explicitly itemized by any step):** `PlacementPDFView.resetAnnotationSelection()` is called from `PDFReaderView.updateNSView` whenever `store.document` identity changes or `store.documentRevision` bumps (covers Undo/Redo, new document, and any other edit path that changes `documentRevision`, including the per-row Inspector delete in the "Chú thích — N" list). This prevents the new on-object frame/popover from ever being drawn or resized against a page/annotation object that no longer belongs to the current document — a correctness requirement directly implied by the plan's own Risk note ("Deselect on page change / document change") and necessary for the persistent selection state Step 4 introduces (the old transient `draggedAnnotation` never had this problem since it was cleared at every `mouseUp`).
- **Small caption-text deviation in `AnnotationEditPopover.imageSection`:** the plan says to transplant sections "verbatim," but the image section's original caption ("...Đổi kích thước rồi nhấn Áp dụng") referenced the width/height steppers + "Áp dụng kích thước" button that Step 3 explicitly drops ("size now via handles"). Left verbatim, the caption would reference controls that no longer exist in that section. Updated the one sentence to "Kéo để di chuyển, kéo góc để đổi kích thước." — no other section text was changed.
- **`view.setAccessibilityHelp` string in `PDFReaderView.makeNSView`** (not itemized by any step) previously said annotations are edited "trong bảng Thông tin" (in the Info panel) — now false, since editing moved to the popover. Updated to "chỉnh sửa ngay trên trang" (edit right on the page) since leaving a11y text describing removed functionality seemed like a real correctness issue directly caused by this feature, not a style nit.
- **No dead code left behind.** Grep-confirmed zero references to `onAnnotationSelected`, `annotationPositionControls` (except one doc-comment noting where it moved from), and `updateSelectedImageSize`. `selectedAnnotationWidth`/`selectedAnnotationHeight` (in `Stores/DocumentStore.swift`, out of every step's scope) are still populated by `selectAnnotation` but have no remaining UI reader now that the image-size steppers are gone — left as-is since `DocumentStore.swift` itself isn't touched by any step and the fields are harmless (still meaningful as "last known annotation size" state, just currently unconsumed).
