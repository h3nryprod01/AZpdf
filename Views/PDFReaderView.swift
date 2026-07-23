import PDFKit
import SwiftUI
import AZpdfCore

struct PDFReaderView: NSViewRepresentable {
    @Bindable var store: DocumentStore

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PlacementPDFView {
        let view = PlacementPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.setAccessibilityLabel("Trình đọc PDF")
        view.setAccessibilityHelp("Chọn văn bản để tô sáng hoặc redact. Chọn chú thích để chỉnh sửa ngay trên trang.")
        view.document = store.document
        view.onPlace = { action, page, bounds in
            place(action, on: page, bounds: bounds)
        }
        view.onSelectAnnotation = { annotation, page in
            let index = store.document?.index(for: page)
            store.selectAnnotation(annotation, pageIndex: index == NSNotFound ? nil : index)
        }
        view.onBeginMoveAnnotation = { store.beginAnnotationMove() }
        view.onFinishMoveAnnotation = { store.finishAnnotationMove() }
        view.onBeginResizeAnnotation = { store.beginAnnotationResize() }
        view.onFinishResizeAnnotation = { bounds in store.resizeSelectedAnnotation(to: bounds) }
        view.onDeleteSelected = { store.deleteSelectedAnnotation() }
        view.onMoveSelected = { store.moveSelectedAnnotation(horizontal: $0.width, vertical: $0.height) }
        view.makePopoverContent = { [weak view] in
            NSHostingController(rootView: AnnotationEditPopover(store: store, onDelete: { view?.deleteSelected() }))
        }
        view.onOCRRegion = { page, bounds in
            guard let index = store.document?.index(for: page) else { return }
            guard index != NSNotFound else { return }
            store.beginOCRRegion(pageIndex: index, bounds: bounds)
        }
        return view
    }

    func updateNSView(_ view: PlacementPDFView, context: Context) {
        if view.document !== store.document {
            view.document = store.document
            // A new document means any on-object selection frame is anchored
            // to a page/annotation from the discarded document — drop it.
            view.resetAnnotationSelection()
        }
        // Edits that mutate the document in place — deleting an annotation, for
        // example — keep the same PDFDocument identity, so the check above
        // cannot catch them. The store bumps documentRevision for exactly this
        // reason; reading it here both registers the observation dependency and
        // tells us when to force PDFView to redraw. Without it a deleted
        // annotation stays on screen and the edit looks like it failed.
        if context.coordinator.documentRevision != store.documentRevision {
            context.coordinator.documentRevision = store.documentRevision
            view.layoutDocumentView()
            // Undo/redo replace the whole PDFDocument object graph, which can
            // leave the selection frame pointing at a stale page/annotation —
            // clear it rather than risk drawing or resizing a detached object.
            view.resetAnnotationSelection()
        }
        if store.isAutoScale {
            view.autoScales = true
        } else {
            view.autoScales = false
            if abs(view.scaleFactor - store.zoomScale) > 0.01 { view.scaleFactor = store.zoomScale }
        }
        if let page = store.document?.page(at: store.selectedPageIndex), context.coordinator.pageIndex != store.selectedPageIndex {
            view.go(to: page)
            context.coordinator.pageIndex = store.selectedPageIndex
        }
        if store.searchText != context.coordinator.searchText {
            context.coordinator.searchText = store.searchText
            context.coordinator.searchResults = store.searchText.isEmpty ? [] : (view.document?.findString(store.searchText, withOptions: .caseInsensitive) ?? [])
            context.coordinator.searchIndex = context.coordinator.searchResults.isEmpty ? -1 : 0
            store.searchResultCount = context.coordinator.searchResults.count
            store.searchResultIndex = context.coordinator.searchResults.isEmpty ? 0 : 1
            if let match = context.coordinator.searchResults.first {
                view.currentSelection = match
                view.go(to: match)
            }
        }
        if context.coordinator.searchNavigationID != store.searchNavigationID {
            context.coordinator.searchNavigationID = store.searchNavigationID
            showSearchResult(in: view, coordinator: context.coordinator)
        }
        if context.coordinator.actionID != store.readerActionID {
            context.coordinator.actionID = store.readerActionID
            perform(store.readerAction, in: view)
        }
    }

    private func perform(_ action: PDFReaderAction, in view: PlacementPDFView) {
        guard let document = view.document else { return }
        let page = view.currentPage ?? document.page(at: store.selectedPageIndex)
        guard let page else { return }
        store.selectedPageIndex = document.index(for: page)

        switch action {
        case .none:
            view.clearPlacement()
        case .addNote:
            let cropBox = page.bounds(for: .cropBox)
            let noteBounds = CGRect(x: cropBox.minX + 40, y: cropBox.maxY - 132, width: 190, height: 76)
            let annotation = PDFAnnotation(bounds: noteBounds, forType: .freeText, withProperties: nil)
            annotation.contents = "Nhập ghi chú…"
            annotation.userName = "AZpdf Note"
            annotation.font = .systemFont(ofSize: 13)
            annotation.fontColor = .labelColor
            annotation.color = NSColor.systemOrange.withAlphaComponent(0.9)
            annotation.interiorColor = NSColor.systemYellow.withAlphaComponent(0.25)
            page.addAnnotation(annotation)
            store.selectAnnotation(annotation, pageIndex: store.selectedPageIndex)
            store.record(.addAnnotation(kind: .note, page: store.selectedPageIndex))
        case .highlightSelection:
            guard let selection = view.currentSelection else {
                store.lastError = "Hãy chọn đoạn văn bản trước khi tô sáng."
                return
            }
            for selectionPage in selection.pages {
                let bounds = selection.bounds(for: selectionPage)
                guard !bounds.isNull, !bounds.isEmpty else { continue }
                let annotation = PDFAnnotation(bounds: bounds.insetBy(dx: -1, dy: -1), forType: .highlight, withProperties: nil)
                annotation.color = NSColor.systemYellow.withAlphaComponent(0.45)
                selectionPage.addAnnotation(annotation)
            }
            view.clearSelection()
            store.record(.addAnnotation(kind: .highlight, page: store.selectedPageIndex))
        case .freeText, .signature, .image, .shape:
            view.armPlacement(action)
        case .ocrRegion:
            view.armOCRRegionSelection()
        case .redactSelection:
            guard let selection = view.currentSelection else {
                store.lastError = "Hãy chọn nội dung cần redact trước."
                return
            }
            let regions = selection.pages.compactMap { selectionPage -> (pageIndex: Int, bounds: CGRect)? in
                let bounds = selection.bounds(for: selectionPage)
                let index = document.index(for: selectionPage)
                guard index != NSNotFound, !bounds.isNull, !bounds.isEmpty else { return nil }
                return (index, bounds.insetBy(dx: -1, dy: -1))
            }
            guard store.permanentlyRedact(regions) else {
                store.lastError = "Không thể redact vùng đã chọn."
                return
            }
            view.clearSelection()
            view.document = store.document
            store.record(.redact(pages: regions.map(\.pageIndex)))
        }
    }

    private func place(_ action: PDFReaderAction, on page: PDFPage, bounds: CGRect) {
        guard let document = store.document else { return }
        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else { return }
        switch action {
        case let .freeText(text):
            store.prepareAnnotationPlacement()
            let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.font = .systemFont(ofSize: 14)
            annotation.fontColor = .labelColor
            annotation.color = .clear
            page.addAnnotation(annotation)
            store.finishAnnotationPlacement(.addAnnotation(kind: .freeText, page: pageIndex))
        case let .signature(strokes):
            store.prepareAnnotationPlacement()
            let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            annotation.color = .labelColor
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                let path = NSBezierPath()
                path.move(to: Self.signaturePoint(first, in: bounds))
                for point in stroke.points.dropFirst() { path.line(to: Self.signaturePoint(point, in: bounds)) }
                annotation.add(path)
            }
            page.addAnnotation(annotation)
            store.finishAnnotationPlacement(.addAnnotation(kind: .signature, page: pageIndex))
        case let .image(url):
            store.insertImageOverlay(from: url, pageIndex: pageIndex, bounds: bounds)
        case let .shape(kind):
            store.prepareAnnotationPlacement()
            let annotation = ShapeAnnotationFactory.make(
                kind,
                bounds: bounds,
                stroke: store.shapeStrokeColor,
                fill: kind.supportsFill ? store.shapeFillColor : nil,
                lineWidth: store.shapeLineWidth
            )
            page.addAnnotation(annotation)
            store.finishAnnotationPlacement(.addAnnotation(kind: .shape, page: pageIndex))
        default:
            return
        }
    }

    /// Returns a point in annotation-local space, i.e. relative to the ink
    /// annotation's own bounds origin — NOT page space. PDFKit adds
    /// `bounds.origin` when it writes `/InkList`, so returning page
    /// coordinates here offsets every stroke by the origin a second time and
    /// pushes the whole signature outside `/Rect`, where every viewer clips it
    /// away. The signature then exists in the file but renders nowhere.
    static func signaturePoint(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(x: point.x / SignatureCanvasMetrics.size.width * bounds.width,
                y: bounds.height - point.y / SignatureCanvasMetrics.size.height * bounds.height)
    }

    private func showSearchResult(in view: PDFView, coordinator: Coordinator) {
        guard !coordinator.searchResults.isEmpty else { return }
        coordinator.searchIndex = (coordinator.searchIndex + store.searchDirection + coordinator.searchResults.count) % coordinator.searchResults.count
        let match = coordinator.searchResults[coordinator.searchIndex]
        store.searchResultIndex = coordinator.searchIndex + 1
        view.currentSelection = match
        view.go(to: match)
    }

    final class Coordinator {
        var pageIndex = -1
        var documentRevision = -1
        var searchText = ""
        var searchResults: [PDFSelection] = []
        var searchIndex = -1
        var searchNavigationID = 0
        var actionID = -1
    }
}

final class PlacementPDFView: PDFView {
    var onPlace: ((PDFReaderAction, PDFPage, CGRect) -> Void)?
    var onSelectAnnotation: ((PDFAnnotation?, PDFPage) -> Void)?
    var onBeginMoveAnnotation: (() -> Void)?
    var onFinishMoveAnnotation: (() -> Void)?
    var onBeginResizeAnnotation: (() -> Void)?
    var onFinishResizeAnnotation: ((CGRect) -> Void)?
    var onOCRRegion: ((PDFPage, CGRect) -> Void)?
    var onDeleteSelected: (() -> Void)?
    var onMoveSelected: ((CGSize) -> Void)?
    /// Builds the popover's SwiftUI content on demand. A closure rather than a
    /// stored `DocumentStore` reference — the view reports through closures
    /// and never holds the store directly (see `onSelectAnnotation` etc.).
    var makePopoverContent: (() -> NSViewController)?
    private var placementAction: PDFReaderAction?
    private var draggedAnnotation: PDFAnnotation?
    private var dragPage: PDFPage?
    private var dragStartPoint: CGPoint?
    private var dragStartBounds: CGRect?
    private var ocrRegionPage: PDFPage?
    private var ocrRegionStartInView: CGPoint?
    private var ocrRegionCurrentInView: CGPoint?

    // On-object selection frame + resize state.
    private var selectedAnnotation: PDFAnnotation?
    private var selectedPage: PDFPage?
    private var activeHandle: AnnotationHandles.Handle?
    private var resizeStartBounds: CGRect?
    private static let handleSize: CGFloat = 8
    private lazy var editPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        return popover
    }()
    /// Transparent, click-through subview that paints the persistent
    /// on-object selection frame + handles. PDFView renders actual page
    /// pixels via a nested `PDFPageView`/`PDFPageLayer` several levels deep
    /// inside its own `PDFScrollView` subview — a full-bounds subview added
    /// at PDFKit's own init time, which by ordinary AppKit z-order always
    /// composites *above* anything this view draws directly in its own
    /// draw(_:). That nested layer re-renders asynchronously (confirmed:
    /// `convert(_:from:)` returns a correct on-screen rect every time, so
    /// the frame was never actually missing — it was being drawn, then
    /// immediately painted over). The continuously-redrawn OCR drag rect
    /// "works" only because it keeps re-winning that race every
    /// mouseDragged; a one-shot static frame always loses it. A dedicated
    /// topmost subview added after PDFScrollView sidesteps the race
    /// entirely. hitTest always returns nil, so mouse events still reach
    /// this view unchanged — hit-testing/resize/popover logic stays here.
    private lazy var selectionOverlay: AnnotationSelectionOverlayView = {
        let overlay = AnnotationSelectionOverlayView()
        overlay.host = self
        overlay.autoresizingMask = [.width, .height]
        overlay.setAccessibilityElement(false)
        addSubview(overlay)
        return overlay
    }()

    func armPlacement(_ action: PDFReaderAction) {
        placementAction = action
        window?.invalidateCursorRects(for: self)
    }

    func clearPlacement() {
        placementAction = nil
        clearOCRRegionSelection()
        window?.invalidateCursorRects(for: self)
    }

    func armOCRRegionSelection() {
        placementAction = .ocrRegion
        clearOCRRegionSelection()
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if placementAction != nil { addCursorRect(bounds, cursor: .crosshair) }
    }

    override func mouseDown(with event: NSEvent) {
        if placementAction == .ocrRegion {
            let pointInView = convert(event.locationInWindow, from: nil)
            guard let page = page(for: pointInView, nearest: true) else { return }
            ocrRegionPage = page
            ocrRegionStartInView = pointInView
            ocrRegionCurrentInView = pointInView
            needsDisplay = true
            return
        }
        guard let action = placementAction else {
            let pointInView = convert(event.locationInWindow, from: nil)
            // Handles take priority over selecting a (possibly different)
            // annotation underneath them.
            if let handle = activeResizeHandle(at: pointInView) {
                activeHandle = handle
                resizeStartBounds = selectedAnnotation?.bounds
                editPopover.close()
                onBeginResizeAnnotation?()
                return
            }
            guard let page = page(for: pointInView, nearest: true) else {
                resetAnnotationSelection()
                super.mouseDown(with: event)
                return
            }
            let pointOnPage = convert(pointInView, to: page)
            let annotation = page.annotations.reversed().first {
                !$0.isAZpdfPopup && $0.bounds.contains(pointOnPage)
            }
            onSelectAnnotation?(annotation, page)
            editPopover.close()
            if annotation != nil { window?.makeFirstResponder(self) }
            guard let annotation, isMovable(annotation) else {
                resetAnnotationSelection()
                super.mouseDown(with: event)
                return
            }
            selectedAnnotation = annotation
            selectedPage = page
            needsDisplay = true
            clearSelection()
            draggedAnnotation = annotation
            dragPage = page
            dragStartPoint = pointOnPage
            dragStartBounds = annotation.bounds
            onBeginMoveAnnotation?()
            return
        }
        let pointInView = convert(event.locationInWindow, from: nil)
        guard let page = page(for: pointInView, nearest: true) else { return }
        let pointOnPage = convert(pointInView, to: page)
        placementAction = nil
        window?.invalidateCursorRects(for: self)
        onPlace?(action, page, placementBounds(for: action, at: pointOnPage, on: page))
    }

    override func mouseDragged(with event: NSEvent) {
        if placementAction == .ocrRegion, ocrRegionPage != nil {
            ocrRegionCurrentInView = convert(event.locationInWindow, from: nil)
            needsDisplay = true
            return
        }
        if let handle = activeHandle, let annotation = selectedAnnotation, let page = selectedPage, let startBounds = resizeStartBounds {
            let pointOnPage = convert(convert(event.locationInWindow, from: nil), to: page)
            let shiftDown = event.modifierFlags.contains(.shift)
            let aspectLocked = annotation.isAZpdfFreeformResize ? shiftDown : !shiftDown
            annotation.bounds = AnnotationHandles.resizedBounds(
                original: startBounds,
                handle: handle,
                to: pointOnPage,
                aspectLocked: aspectLocked,
                minSize: CGSize(width: 24, height: 24),
                within: page.bounds(for: .cropBox)
            )
            // A line's endpoints and an ink shape's paths do not follow bounds.
            annotation.refreshAZpdfShapeGeometry()
            needsDisplay = true
            return
        }
        guard let annotation = draggedAnnotation,
              let page = dragPage,
              let startPoint = dragStartPoint,
              let startBounds = dragStartBounds else {
            super.mouseDragged(with: event)
            return
        }
        let pointInView = convert(event.locationInWindow, from: nil)
        let pointOnPage = convert(pointInView, to: page)
        let cropBox = page.bounds(for: .cropBox)
        let candidate = startBounds.offsetBy(dx: pointOnPage.x - startPoint.x, dy: pointOnPage.y - startPoint.y)
        annotation.bounds = CGRect(
            x: min(max(candidate.minX, cropBox.minX), cropBox.maxX - candidate.width),
            y: min(max(candidate.minY, cropBox.minY), cropBox.maxY - candidate.height),
            width: candidate.width,
            height: candidate.height
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if placementAction == .ocrRegion,
           let page = ocrRegionPage,
           let start = ocrRegionStartInView {
            let end = convert(event.locationInWindow, from: nil)
            let startOnPage = convert(start, to: page)
            let endOnPage = convert(end, to: page)
            let bounds = CGRect(
                x: min(startOnPage.x, endOnPage.x),
                y: min(startOnPage.y, endOnPage.y),
                width: abs(endOnPage.x - startOnPage.x),
                height: abs(endOnPage.y - startOnPage.y)
            ).intersection(page.bounds(for: .cropBox))
            placementAction = nil
            clearOCRRegionSelection()
            window?.invalidateCursorRects(for: self)
            if bounds.width >= 8, bounds.height >= 8 { onOCRRegion?(page, bounds) }
            return
        }
        if activeHandle != nil, let annotation = selectedAnnotation {
            activeHandle = nil
            resizeStartBounds = nil
            onFinishResizeAnnotation?(annotation.bounds)
            presentPopover()
            return
        }
        if draggedAnnotation != nil {
            draggedAnnotation = nil
            dragPage = nil
            dragStartPoint = nil
            dragStartBounds = nil
            onFinishMoveAnnotation?()
            presentPopover()
            return
        }
        super.mouseUp(with: event)
    }

    private func isMovable(_ annotation: PDFAnnotation) -> Bool {
        annotation.isAZpdfMovable
    }

    /// Hit-tests the selected annotation's handles in view space. Returns nil
    /// when nothing is selected, the type has no handles (e.g. a note), or the
    /// point misses every handle square.
    private func activeResizeHandle(at pointInView: CGPoint) -> AnnotationHandles.Handle? {
        guard let selectedAnnotation, let selectedPage, selectedAnnotation.isAZpdfResizable else { return nil }
        let viewRect = convert(selectedAnnotation.bounds, from: selectedPage)
        guard case let .handle(handle) = AnnotationHandles(rect: viewRect, handleSize: Self.handleSize)
            .hit(pointInView, includeEdges: selectedAnnotation.isAZpdfFreeformResize) else { return nil }
        return handle
    }

    /// Clears the on-object selection frame + popover without touching the
    /// store. Called on deselect (empty space, Esc) and whenever the document
    /// is replaced or edited elsewhere (Undo/redo, a new document), so the
    /// view never draws or resizes a page/annotation that no longer belongs
    /// to the current document.
    func resetAnnotationSelection() {
        selectedAnnotation = nil
        selectedPage = nil
        needsDisplay = true
        editPopover.close()
    }

    /// Presents the caret popover anchored to the current selection.
    private func presentPopover() {
        guard let selectedAnnotation, let selectedPage, let makePopoverContent else { return }
        editPopover.contentViewController = makePopoverContent()
        let viewRect = convert(selectedAnnotation.bounds, from: selectedPage)
        editPopover.show(relativeTo: viewRect, of: self, preferredEdge: .maxY)
    }

    /// Single path for removing the selected annotation — used by the Delete
    /// key and the popover's "Xóa" button — so the view's frame and popover
    /// never linger over an annotation the store just deleted.
    func deleteSelected() {
        onDeleteSelected?()
        resetAnnotationSelection()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // 51 = Delete (backspace), 117 = Forward Delete. Remove the selected
        // annotation in place — the natural gesture users expect after clicking
        // a signature or image.
        if event.keyCode == 51 || event.keyCode == 117, onDeleteSelected != nil {
            deleteSelected()
            return
        }
        // Arrow keys nudge the selection. This is the non-drag way to move an
        // annotation — keyboard and VoiceOver users have no other one now that
        // the popover's move buttons are gone. Shift makes it a coarse step.
        if selectedAnnotation != nil, let nudge = Self.arrowNudge(for: event) {
            onMoveSelected?(nudge)
            return
        }
        // 53 = Escape. Only consume it when there is a selection to drop, so an
        // idle Esc keeps falling through to whatever handled it before.
        if event.keyCode == 53, selectedAnnotation != nil {
            if let selectedPage { onSelectAnnotation?(nil, selectedPage) }
            resetAnnotationSelection()
            return
        }
        super.keyDown(with: event)
    }

    /// Right-click an annotation to select and delete it without hunting through
    /// the inspector list.
    override func menu(for event: NSEvent) -> NSMenu? {
        let pointInView = convert(event.locationInWindow, from: nil)
        guard let page = page(for: pointInView, nearest: true) else { return super.menu(for: event) }
        let pointOnPage = convert(pointInView, to: page)
        guard let annotation = page.annotations.reversed().first(where: {
            !$0.isAZpdfPopup && $0.bounds.contains(pointOnPage)
        }) else { return super.menu(for: event) }
        onSelectAnnotation?(annotation, page)
        window?.makeFirstResponder(self)
        let menu = NSMenu()
        let delete = NSMenuItem(title: "Xóa chú thích", action: #selector(deleteSelectedFromMenu), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)
        return menu
    }

    @objc private func deleteSelectedFromMenu() { onDeleteSelected?() }

    /// 123–126 are the four arrow keys. Returns the page-space offset to move
    /// by, or nil if this was not an arrow key.
    static func arrowNudge(for event: NSEvent) -> CGSize? {
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 16 : 2
        return switch event.keyCode {
        case 123: CGSize(width: -step, height: 0)
        case 124: CGSize(width: step, height: 0)
        case 125: CGSize(width: 0, height: -step)
        case 126: CGSize(width: 0, height: step)
        default: nil
        }
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        // Keeps the overlay sized and repainted in lockstep with every
        // reason this view redraws: select/move/resize set our own
        // needsDisplay explicitly; scroll and page navigation are driven by
        // PDFKit internally and were confirmed (headless PDFView probe) to
        // still invoke viewWillDraw even on passes where draw(_:) itself is
        // skipped, so this is the reliable hook, not draw(_:).
        selectionOverlay.frame = bounds
        selectionOverlay.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let start = ocrRegionStartInView, let current = ocrRegionCurrentInView else { return }
        let rect = CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y)
        )
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        NSBezierPath(rect: rect).fill()
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    }

    /// Called from `AnnotationSelectionOverlayView.draw(_:)` — see
    /// `selectionOverlay`'s doc comment for why this must run in that
    /// dedicated topmost view rather than directly in this view's draw(_:).
    fileprivate func drawSelectionOverlayContent() {
        guard let selectedAnnotation, let selectedPage else { return }
        drawSelectionFrame(for: selectedAnnotation, on: selectedPage)
    }

    /// Draws the accent selection frame in view space, plus resize handles for
    /// resizable types — 8 handles (corners + edges) for free-text, 4 corner
    /// handles for image/ink, none for a note.
    private func drawSelectionFrame(for annotation: PDFAnnotation, on page: PDFPage) {
        let viewRect = convert(annotation.bounds, from: page)
        NSColor.controlAccentColor.setStroke()
        let frame = NSBezierPath(rect: viewRect)
        if annotation.isAZpdfFreeText || annotation.isAZpdfNote {
            // A text box usually has no border of its own, so a solid 2 pt
            // frame reads as part of the content. A hairline dashed frame reads
            // as selection — the same distinction Preview draws.
            frame.lineWidth = 1
            frame.setLineDash([4, 3], count: 2, phase: 0)
        } else {
            frame.lineWidth = 2
        }
        frame.stroke()
        guard annotation.isAZpdfResizable else { return }
        let handles = AnnotationHandles(rect: viewRect, handleSize: Self.handleSize)
        for (_, handleRect) in handles.handleRects(includeEdges: annotation.isAZpdfFreeformResize) {
            let handlePath = NSBezierPath(rect: handleRect)
            NSColor.white.setFill()
            handlePath.fill()
            NSColor.controlAccentColor.setStroke()
            handlePath.lineWidth = 1.5
            handlePath.stroke()
        }
    }

    private func clearOCRRegionSelection() {
        ocrRegionPage = nil
        ocrRegionStartInView = nil
        ocrRegionCurrentInView = nil
        needsDisplay = true
    }

    private func placementBounds(for action: PDFReaderAction, at point: CGPoint, on page: PDFPage) -> CGRect {
        let cropBox = page.bounds(for: .cropBox)
        let size: CGSize = switch action {
        case .freeText: CGSize(width: min(320, max(100, cropBox.width - 32)), height: 52)
        case .signature: CGSize(width: min(260, max(120, cropBox.width - 32)), height: min(96, max(60, cropBox.height - 32)))
        case .image: CGSize(width: min(180, max(80, cropBox.width - 32)), height: min(180, max(80, cropBox.height - 32)))
        case .shape: CGSize(width: min(160, max(60, cropBox.width - 32)), height: min(120, max(60, cropBox.height - 32)))
        default: .zero
        }
        let x = min(max(point.x, cropBox.minX + 16), cropBox.maxX - size.width - 16)
        let y = min(max(point.y - size.height, cropBox.minY + 16), cropBox.maxY - size.height - 16)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

/// Draw-only, click-through subview of `PlacementPDFView` — see
/// `PlacementPDFView.selectionOverlay`'s doc comment for why the selection
/// frame/handles must be drawn here instead of directly in
/// `PlacementPDFView.draw(_:)`. Never hit-tested (`hitTest` always returns
/// nil) so mouse events fall through to `PlacementPDFView` unchanged; all
/// hit-testing, resize, and popover logic stays there.
private final class AnnotationSelectionOverlayView: NSView {
    weak var host: PlacementPDFView?

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        host?.drawSelectionOverlayContent()
    }
}
