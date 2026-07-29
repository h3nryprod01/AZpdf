# Plan — Direct-manipulation annotation editing (macOS AZpdf)

## Goal
Selecting a placed annotation draws an accent selection frame **on the object** (8 handles
for free-text, 4 corner handles for image/ink, no handles for notes) and shows a caret
`NSPopover` with type-specific edit controls. Dragging a corner/edge resizes in page space
(aspect-locked for image/ink, free for free-text, Shift inverts, clamped to 24×24 and the
cropBox). The four type-specific edit **sections leave the Inspector** and live only in the
popover. Resize is one undo step; the resize maths is a pure, GUI-free, unit-tested struct.

## Context discovered
- Build: `AZpdf` executable target is `path: "."`, `sources: ["App","Models","Services","Stores","Support","Views"]` — new files in `Models/` and `Views/` are picked up automatically. **No `Package.swift` edit needed** (and it is MUST-NOT-touch anyway). Both `AZpdf` and `AZpdfTests` are `#if os(macOS)`; tests run on macOS. Incremental `swift build` ≈ 6s.
- `Views/PDFReaderView.swift`: `PlacementPDFView` already overrides `draw()` (OCR-region rect, lines 379-392), `mouseDown/Dragged/Up` (246-340), `keyDown` (Delete=51/117, 348-357), `menu(for:)` (right-click delete, 361-375). Selection is reported up via closures (`onSelectAnnotation`, `onBeginMoveAnnotation`, `onFinishMoveAnnotation`, `onDeleteSelected`); the view holds **no** store reference — keep that pattern.
- Move flow to mirror for resize: `mouseDown` → `onBeginMoveAnnotation` (`store.beginAnnotationMove()` = `registerUndoStep()`, snapshots doc **before** mutation) → `mouseDragged` mutates `annotation.bounds` live → `mouseUp` → `onFinishMoveAnnotation` (`isModified = true`). Undo restores because the snapshot predates the live mutation. **Resize must snapshot at drag-start too**, never at commit.
- `Stores/DocumentStore+Annotations.swift`: `selectAnnotation` (10-19) populates `selectedAnnotationText/FontSize/Color/Width/Height` + bumps `annotationSelectionID`. `moveSelectedAnnotation` (91-108) is the tested, self-contained accessible move (clamps to cropBox). `updateSelectedFreeText/Ink/Note` register undo + set props + bump `documentRevision`. `updateSelectedImageSize` (52-63) is called **only** from the inspector image section.
- `Views/DocumentInspectorView.swift`: four `if let annotation = store.selectedAnnotation, annotation.isAZpdfX { Section … }` blocks at **lines 75-133** (free-text, note, image, ink); private helpers `deleteSelectedButton` (150-152) and `annotationPositionControls` (154-179) are used **only** by those four blocks.
- `Views/ContentView.swift`: selecting an annotation force-opens the Inspector in **two** places — the `PDFReaderView { hasSelection in if hasSelection { store.isInspectorPresented = true } }` closure (23-25) and `.onChange(of: store.annotationSelectionID)` (90-92). `annotationSelectionID`'s only reader is that onChange (grep-confirmed). The popover replaces this; both must go or the panel fights the popover.
- `Models/PDFAnnotation+AZpdf.swift`: flags `isAZpdfNote/FreeText/Image(stamp)/Ink/Movable`. `isAZpdfMovable = [freetext, ink, stamp, text]`.
- `Models/EditableImageAnnotation.swift`: `draw(with:in:)` draws its `NSImage` into `bounds` — image always fills bounds, so it rescales cleanly on resize (low clip risk). **Ink is the risk**: `/InkList` is absolute inside `/Rect`; changing bounds makes PDFKit scale the appearance (the "bug F" family — see `Tests/AZpdfTests/SignaturePointTests.swift`). Ink needs a render-verify.
- Coordinate facts: `convert(bounds, from: page)` → view space (what `draw()` uses; proven by the OCR rect). `convert(pointInView, to: page)` → page space. Handles are a constant **screen** size → hit-test + draw in **view space**; resize maths in **page space**.
- `Views/EscapeDismissInstaller.swift` installs a `.keyDown` monitor for Esc (53) **only while a sheet is shown**, so adding Esc handling to `PlacementPDFView.keyDown` won't conflict. The view already `makeFirstResponder(self)` on select, so it receives keyDown.
- Test/build commands confirmed: `swift build --package-path <dir>`, `swift test --package-path <dir> --filter <Suite>`, `./script/build_and_run.sh --bundle` (assembles the .app, no run).

## Approach
Keep the AppKit ownership the spec chose. **`PlacementPDFView` owns the on-object selection**
(`selectedAnnotation`/`selectedPage` for drawing + popover anchor) and mirrors it to the store
via the existing `onSelectAnnotation` closure (so the store's edit bindings + inspector list
stay populated). A new pure struct **`AnnotationHandles`** (CoreGraphics only) does all handle
geometry, hit-testing, and the resize/aspect/clamp maths — the error-prone part — so it is
unit-tested with no GUI. The **popover is a SwiftUI `AnnotationEditPopover` hosted in an
`NSPopover`**, presented by the view (present on select/mouse-up, close on drag/resize-start
and on deselect); its controls are the four inspector sections transplanted verbatim onto the
existing store bindings/methods. Resize mirrors move for undo: `beginAnnotationResize()`
snapshots at drag-start, the view mutates `bounds` live, `resizeSelectedAnnotation(to:)` commits
on mouse-up. This reuses every existing store method and the proven move/OCR view patterns, so
the net-new logic is concentrated in the one testable struct.

Handle policy (resolves a spec ambiguity): **free-text = 8 handles (4 corners + 4 edges);
image & ink = 4 corner handles only.** This matches the spec line "edge handle (**free-text
only**): change one dimension" and removes any need for a locked-edge case in the maths. Aspect
lock: `aspectLocked = isFreeText ? shiftDown : !shiftDown` (image/ink locked by default,
free-text free by default; Shift inverts).

## Alternatives considered
- **Store owns selection; `updateNSView` drives the popover open/close.** Rejected: "hide during
  drag, reappear on mouse-up" needs the view to open/close the popover directly on mouse events;
  routing it through `@Observable` → `updateNSView` can't see a drag start/end and would lag.
- **Auto-present the popover on placement (place-a-note → immediately editable).** Rejected as
  scope creep: needs a store→view selection-adoption sync (loop-guarded via `annotationSelectionID`).
  Spec's interaction model is "click an object → select"; a placed note is one click from editing.
- **8 handles for every resizable type (locked edges scale proportionally).** Rejected: extra
  maths for a case the spec explicitly scopes to free-text; 4-corners-for-image/ink is simpler and
  matches "edge handle (free-text only)".
- **Pure-SwiftUI overlay for frame/handles.** Rejected by the spec (fragile under scroll/zoom).

## Risks
- **Ink render after resize (highest).** `/InkList` is absolute in `/Rect`; PDFKit rescales on
  bounds change and can clip/lose the signature (bug F). Mitigation: Step 6 raster render-verify
  after a round-trip through `dataRepresentation()`.
- **Accessibility regression.** Removing the four inspector sections also removes
  `annotationPositionControls` — today's only keyboard/VoiceOver move affordance (drag isn't
  keyboard-accessible; the spec's popover contents omit move controls). `moveSelectedAnnotation`
  stays (tested), but it loses its UI trigger. **Decision for reviewer:** ship spec-literal, or
  relocate `annotationPositionControls` into the popover (small, a11y-preserving). Plan defaults to
  spec-literal and flags it; see Step 5 optional sub-item.
- **NSPopover `.transient` vs. drag.** Mousing down to drag/resize may auto-dismiss the transient
  popover before our handler; we explicitly `close()` on drag/resize-start and re-`show` on
  mouse-up, so the auto-dismiss is harmless. Watch for a flash on same-object re-selection.
- **Divide-by-zero** in aspect-locked scale when a bounds w or h is 0 — guard in `resizedBounds`
  (return original/min). Covered by a unit test.
- **Selection/store drift**: popover "Xóa" and the Delete key mutate the store; the view must also
  clear its own selection + close the popover in the same action (single `deleteSelected()` path),
  or a frame lingers over a deleted annotation.

## Steps
- [x] 1. **`Models/AnnotationHandles.swift`** (new, pure; `import CoreGraphics` only — no PDFKit/AppKit/SwiftUI). `enum Handle { topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left; var isCorner }`; `enum Hit: Equatable { case handle(Handle), body, none }`. Init with a rect + handleSize (view space). `handleRects(includeEdges: Bool) -> [Handle: CGRect]` (squares centred on corners + edge-mids); `hit(_ point:, includeEdges:) -> Hit` (handle > body > none). `static func resizedBounds(original:, handle:, to point:, aspectLocked:, minSize:, within pageBounds:) -> CGRect`: corner anchors opposite corner (free = independent; locked = `scale = max(|dx|/w, |dy|/h)` preserving w/h, guard w==0||h==0); edge changes only its axis; then enforce minSize and `.intersection(pageBounds)`. **All clamping lives here.** → verify: written together with test in Step-1b.
- [x] 1b. **`Tests/AZpdfTests/AnnotationHandlesTests.swift`** (new): handle-rect centres; `hit` priority (corner-point→handle, inside→body, outside→none); `resizedBounds` for corner-free, corner-locked (ratio preserved + even scale), horizontal edge, vertical edge, min-size clamp, cropBox clamp, and w==0 divide-by-zero guard. → verify: `swift test --package-path <dir> --filter AnnotationHandlesTests`. ✓ 11/11 pass.
- [x] 2. **`Stores/DocumentStore+Annotations.swift`**: add `beginAnnotationResize()` = `registerUndoStep()` (mirrors `beginAnnotationMove`, lines 21-23); add `resizeSelectedAnnotation(to newBounds: CGRect)` = set `selectedAnnotation?.bounds` (cheap `max(24,…)` floor), `modificationDate = Date()`, `isModified = true`, `documentRevision += 1` — **no** `registerUndoStep` (the begin owns undo). Remove now-orphaned `updateSelectedImageSize()` (52-63). Add store test `testResizeSelectedAnnotationCommitsAndUndoRestores` (selectAnnotation → beginAnnotationResize → resizeSelectedAnnotation → assert bounds+isModified+canUndo → undo → assert original bounds) in `DocumentStoreTests.swift`. Optionally add `var isAZpdfResizable { isAZpdfFreeText || isAZpdfInk || isAZpdfImage }` to `Models/PDFAnnotation+AZpdf.swift`. → verify: `swift test --package-path <dir> --filter DocumentStoreTests`. ✓ (note: this step's own verify only went green once Steps 3-5 landed — see code-summary "Notes for reviewer" re: cross-step compile coupling.)
- [x] 3. **`Views/AnnotationEditPopover.swift`** (new SwiftUI): `struct AnnotationEditPopover: View { @Bindable var store: DocumentStore; let onDelete: () -> Void }`. Transplant the four sections from `DocumentInspectorView.swift:75-133` verbatim, switched on `store.selectedAnnotation` flags — free-text (`TextEditor` + font stepper 8…72 + `ColorPicker` + "Áp dụng" → `updateSelectedFreeText`), ink (`ColorPicker` + "Áp dụng màu" → `updateSelectedInk`), image ("Thay ảnh…" → `beginReplaceSelectedImage`; size now via handles), note (`TextEditor` + "Áp dụng" → `updateSelectedNote`). Common destructive **"Xóa"** calls `onDelete` (view clears selection + closes popover), not the store directly. Keep it compact (fixed width ~300). → verify: `swift build --package-path <dir>`. ✓
- [x] 4. **`Views/PDFReaderView.swift` — `PlacementPDFView`**: add `selectedAnnotation`/`selectedPage`, `activeHandle`/`resizeStartBounds` resize state, and a lazy `NSPopover` + `NSHostingController`. Extend `draw()` (after line 392) to draw an accent frame `convert(selectedAnnotation.bounds, from: selectedPage)` + handle squares via `AnnotationHandles` (edges only when `isAZpdfFreeText`; none when note). In `mouseDown` no-placement branch (256-274): **first** if a resizable annotation is selected and `AnnotationHandles(viewRect,size).hit(pointInView, includeEdges: isFreeText) == .handle(h)` → begin resize (`onBeginResize?()` = `store.beginAnnotationResize()`, close popover, return); **else** existing annotation-under-point select — set view selection for movable types (`needsDisplay`), `onSelectAnnotation`, begin move, close popover; **else** deselect (clear view selection, close popover, `onSelectAnnotation(nil,page)`) then `super`. In `mouseDragged` add a resize branch: `newBounds = AnnotationHandles.resizedBounds(original: resizeStartBounds, handle: activeHandle, to: convert(pt,to:page), aspectLocked: isFreeText ? shift : !shift, minSize: 24×24, within: page.bounds(.cropBox))`, set `annotation.bounds`, `needsDisplay`. In `mouseUp` add a resize branch → `store.resizeSelectedAnnotation(to: annotation.bounds)` (via a new `onFinishResize` closure) + present popover; also present popover at the end of the existing move-finish branch. Add a `deleteSelected()` helper (`onDeleteSelected?()` + clear view selection + close popover) used by keyDown-Delete and the popover. Add Esc (keyCode 53) in `keyDown` → deselect. Wire the new closures in `PDFReaderView.makeNSView`. Present popover: `popover.show(relativeTo: convert(bounds,from:page), of: self, preferredEdge: .maxY)`, `behavior = .transient`, content = `NSHostingController(rootView: AnnotationEditPopover(store: store, onDelete: { self.deleteSelected() }))`. → verify: `swift build --package-path <dir>` + manual GUI (frame, handles, resize, caret popover, aspect lock). ✓ build; manual GUI deferred to tester (no interactive session here).
- [x] 5. **Trim the Inspector wiring**: in `Views/DocumentInspectorView.swift` delete the four sections (75-133) and the now-orphaned `deleteSelectedButton` (150-152) + `annotationPositionControls` (154-179); keep page/document/form sections and the "Chú thích — N" list. In `Views/ContentView.swift` remove the `.onChange(of: store.annotationSelectionID)` auto-open (90-92) and change `PDFReaderView(store: store)` to drop the inspector-opening closure; then remove the now-unused `onAnnotationSelected` param + its call in `Views/PDFReaderView.swift` (7, 26). (Optional a11y sub-item — see Risks: relocate `annotationPositionControls` into `AnnotationEditPopover` for movable types instead of deleting.) → verify: `swift build --package-path <dir>`; grep confirms no dangling `onAnnotationSelected`/`annotationPositionControls`/`updateSelectedImageSize` refs. ✓ a11y sub-item done (Decision #3): relocated into `AnnotationEditPopover` in Step 3, not deleted.
- [x] 6. **Render-verify (ink, "bug F" net)** in `DocumentStoreTests.swift`: build a 1-page doc + an ink annotation with a known stroke, `selectAnnotation`, `beginAnnotationResize` + `resizeSelectedAnnotation(to:)` to a larger rect, round-trip `PDFDocument(data: doc.dataRepresentation()!)` (forces PDFKit to re-render `/InkList` at the new `/Rect`), rasterise the page (`page.thumbnail(of:for:)` → `NSBitmapImageRep`), and assert non-background pixels exist inside the resized bounds (ink not clipped/lost). → verify: `swift test --package-path <dir> --filter DocumentStoreTests`. ✓ (used a saturated-red ink color + full-rect scan instead of a brightness threshold, to stay correct regardless of the synthetic page's background composite — see code-summary.)
- [x] 7. **Full verification**: `swift build --package-path <dir>` → `swift test --package-path <dir>` (all suites green) → `./script/build_and_run.sh --bundle` (app bundle assembles). → verify: all three exit 0. ✓ build 0, test 0 (135 tests, 7 pre-existing skips needing external fixtures, 0 failures), bundle 0 (`dist/AZpdf.app`).

## Out of scope
- Resizing notes; highlights (text-anchored) and redaction frames/handles.
- Rotating annotations; multi-select; re-editing ink strokes (colour + move + resize only).
- Auto-presenting the popover on placement (deliberate — click to edit).
- Any change under `Adapters/`, `Core/`, `Shell/`, or to `Package.swift`.
- Any git push / release — build + test verification only.

## Decisions (locked at plan review — 2026-07-22)
1. Handle policy: free-text = 8 handles; image/ink = 4 corners. (approved)
2. Remove Inspector auto-open in both places. (approved)
3. **A11Y (approved: y + a11y):** do NOT drop keyboard move. In Step 5, instead of
   deleting `annotationPositionControls`, RELOCATE it into `AnnotationEditPopover`
   (Step 3) for movable types, so keyboard/VoiceOver move survives the redesign.
