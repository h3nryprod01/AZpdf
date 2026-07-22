# Direct-manipulation annotation editing (macOS) — design

Status: approved (brainstorm 2026-07-22). Implementation via forge.

## Goal

Editing a placed annotation should happen **on the object**, not in the right-hand
Inspector panel: click to select → a selection frame with resize handles appears on
the object, plus a floating popover (with a caret) holding the type-specific edit
controls. Applies to every movable annotation.

## Scope

- **Frame + popover:** all movable annotations — free-text box, ink signature, image
  (stamp), note. (`isAZpdfMovable` = freetext/ink/stamp/text.)
- **Resize handles:** only the rectangular, scalable types — free-text, ink, image.
  A note is a fixed-size icon: frame + popover but **no** resize handles.
- **Chosen technical approach:** everything in `PlacementPDFView` (AppKit) — draw
  frame/handles in `draw()`, hit-test in `mouseDown`, resize in `mouseDragged`,
  present the popover as an `NSPopover` hosting a SwiftUI content view. (Rejected a
  pure-SwiftUI overlay: keeping it aligned with the PDFView's scroll/zoom is fragile.)

## Interaction model

- Click an object → select: draw an accent-coloured frame around its bounds and, for
  rectangular types, 8 handles (4 corners + 4 edge midpoints); show the popover
  anchored to the object with a caret.
- Drag the body → move (existing behaviour), frame follows.
- Drag a corner handle → resize:
  - image / ink: **keep aspect ratio** (anchor the opposite corner, scale evenly).
  - free-text: **free** (width/height follow the dragged corner independently).
  - edge handle (free-text only): change one dimension.
  - **Shift** inverts the aspect-lock.
  - clamp to min 24×24 and to the page cropBox.
- Click empty space / Escape → deselect: hide frame + dismiss popover.
- Delete / Backspace, or the popover "Xóa", → remove the selected annotation.
- Popover **hides during an active drag** and reappears at the new position on mouse-up
  (simpler and more robust than following in real time).

## Components (each independently understandable/testable)

| Unit | Responsibility | Depends on |
|---|---|---|
| `AnnotationHandles` (new, **pure struct**, no UI) | The maths only: given a view-rect → the 8 handle rects; hit-test a point → `.handle(position)` / `.body` / `.none`; **`resizedBounds(original:handle:to:aspectLocked:)`** → new bounds with aspect + clamp | none |
| `PlacementPDFView` (extend) | Store `selectedAnnotation`/`selectedPage`; draw frame+handles in `draw()`; hit-test handles in `mouseDown`; resize in `mouseDragged`; on mouse-up finalise + show popover; dismiss popover on deselect/drag-start | PDFKit, `AnnotationHandles` |
| `AnnotationEditPopover` (new SwiftUI view) | Popover contents per type; hosted in `NSPopover` via `NSHostingController` | `DocumentStore` |
| `DocumentStore` (extend) | `beginAnnotationResize()` (registerUndoStep) + `resizeSelectedAnnotation(to:)`; keep the existing `updateSelected*` methods for the popover | PDFKit |
| `DocumentInspectorView` (trim) | Remove the four type-specific edit sections (moved to the popover); keep the "Chú thích — N" list, page/document/form info | — |

`AnnotationHandles` being pure is the point: the resize/aspect/clamp maths — the part
most likely to be wrong — is unit-tested without a GUI.

## Resize maths + coordinates

- All computed in **page space** (resolution-independent); PDFKit converts for drawing.
  Draw: `pdfView.convert(bounds, from: page)`. Drag: mouse (view) → page via
  `convert(_:to: page)`.
- `resizedBounds(original:handle:to pagePoint:aspectLocked:)`:
  - corner, aspect-locked (image/ink): anchor opposite corner; new side = original ×
    `max(|dx|/w, |dy|/h)`, preserving `w/h`.
  - corner, free (free-text): anchor opposite corner; width/height follow independently.
  - edge (free-text): change only that edge's dimension.
  - Shift → invert `aspectLocked`.
  - clamp: min 24×24; intersect with `page.bounds(.cropBox)`.
- Apply: `annotation.bounds = newBounds` → `needsDisplay`. `EditableImageAnnotation`
  redraws to the new bounds; ink/free-text scale their appearance.
- **Ink caveat:** `/InkList` is absolute inside `/Rect`; changing bounds makes PDFKit
  scale the appearance. Must render-verify (as done for bug F) that a resized signature
  still draws correctly and is not clipped/lost.

## Popover contents per type

- Common: **Xóa** (destructive).
- Free-text: `TextEditor` (contents) · font-size stepper · colour · "Áp dụng".
- Ink: colour · "Áp dụng màu".
- Image: "Thay ảnh…" (size is now via handles).
- Note: `TextEditor` (contents) · "Áp dụng".

## Undo + edge cases

- Undo: resize registers one undo step at drag start (mirrors move's
  begin/finish); popover edits use the existing undo-registered `updateSelected*`.
- Deselect on page change / document change. Popover dismisses on scroll/drag, returns
  on next selection. Guard divide-by-zero when w or h is 0.

## Testing

- **Pure unit** (`AnnotationHandlesTests`): hit-test point→handle; `resizedBounds` for
  each handle × {locked, free} × clamp → expected bounds. Primary safety net.
- **Store unit**: `resizeSelectedAnnotation` + Undo restores bounds.
- **Render verify** (engine, like bug F): image and signature render correctly after a
  resize — not clipped, not distorted.
- **Manual GUI**: frame/handles appear, resize is smooth, popover has a caret, aspect
  locks for image, free for text.

## Out of scope

- Resizing notes (fixed icon), highlights (text-anchored), redaction.
- Rotating annotations; multi-select.
- Re-editing ink strokes (only colour + move + resize).

## Files

- MAY touch: `Views/PDFReaderView.swift`, `Views/DocumentInspectorView.swift`,
  new `Views/AnnotationEditPopover.swift`, new `Models/AnnotationHandles.swift`,
  `Stores/DocumentStore+Annotations.swift`, `Models/PDFAnnotation+AZpdf.swift`,
  new `Tests/AZpdfTests/AnnotationHandlesTests.swift`, `Tests/AZpdfTests/DocumentStoreTests.swift`.
- MUST NOT touch: `Adapters/*`, `Core/*`, `Package.swift`, the Linux shell.
- Do **not** push or release; build-verify only (`swift build`, `swift test`,
  `./script/build_and_run.sh --bundle`).
