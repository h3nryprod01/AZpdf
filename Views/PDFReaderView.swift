import PDFKit
import SwiftUI
import AZpdfCore

struct PDFReaderView: NSViewRepresentable {
    @Bindable var store: DocumentStore
    var onAnnotationSelected: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PlacementPDFView {
        let view = PlacementPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.setAccessibilityLabel("Trình đọc PDF")
        view.setAccessibilityHelp("Chọn văn bản để tô sáng hoặc redact. Chọn chú thích để chỉnh sửa trong bảng Thông tin.")
        view.document = store.document
        view.onPlace = { action, page, bounds in
            place(action, on: page, bounds: bounds)
        }
        view.onSelectAnnotation = { annotation, page in
            let index = store.document?.index(for: page)
            store.selectAnnotation(annotation, pageIndex: index == NSNotFound ? nil : index)
            onAnnotationSelected(annotation != nil)
        }
        view.onBeginMoveAnnotation = { store.beginAnnotationMove() }
        view.onFinishMoveAnnotation = { store.finishAnnotationMove() }
        view.onOCRRegion = { page, bounds in
            guard let index = store.document?.index(for: page) else { return }
            guard index != NSNotFound else { return }
            store.beginOCRRegion(pageIndex: index, bounds: bounds)
        }
        return view
    }

    func updateNSView(_ view: PlacementPDFView, context: Context) {
        if view.document !== store.document { view.document = store.document }
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
        case .freeText, .signature, .image:
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
                path.move(to: signaturePoint(first, in: bounds))
                for point in stroke.points.dropFirst() { path.line(to: signaturePoint(point, in: bounds)) }
                annotation.add(path)
            }
            page.addAnnotation(annotation)
            store.finishAnnotationPlacement(.addAnnotation(kind: .signature, page: pageIndex))
        case let .image(url):
            store.insertImageOverlay(from: url, pageIndex: pageIndex, bounds: bounds)
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
    private func signaturePoint(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(x: point.x / 520 * bounds.width, y: bounds.height - point.y / 190 * bounds.height)
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
    var onOCRRegion: ((PDFPage, CGRect) -> Void)?
    private var placementAction: PDFReaderAction?
    private var draggedAnnotation: PDFAnnotation?
    private var dragPage: PDFPage?
    private var dragStartPoint: CGPoint?
    private var dragStartBounds: CGRect?
    private var ocrRegionPage: PDFPage?
    private var ocrRegionStartInView: CGPoint?
    private var ocrRegionCurrentInView: CGPoint?

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
            if let page = page(for: pointInView, nearest: true) {
                let pointOnPage = convert(pointInView, to: page)
                let annotation = page.annotations.reversed().first {
                    !$0.isAZpdfPopup && $0.bounds.contains(pointOnPage)
                }
                onSelectAnnotation?(annotation, page)
                if let annotation, isMovable(annotation) {
                    window?.makeFirstResponder(self)
                    clearSelection()
                    draggedAnnotation = annotation
                    dragPage = page
                    dragStartPoint = pointOnPage
                    dragStartBounds = annotation.bounds
                    onBeginMoveAnnotation?()
                    return
                }
            }
            super.mouseDown(with: event)
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
        if draggedAnnotation != nil {
            draggedAnnotation = nil
            dragPage = nil
            dragStartPoint = nil
            dragStartBounds = nil
            onFinishMoveAnnotation?()
            return
        }
        super.mouseUp(with: event)
    }

    private func isMovable(_ annotation: PDFAnnotation) -> Bool {
        annotation.isAZpdfMovable
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
        default: .zero
        }
        let x = min(max(point.x, cropBox.minX + 16), cropBox.maxX - size.width - 16)
        let y = min(max(point.y - size.height, cropBox.minY + 16), cropBox.maxY - size.height - 16)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
