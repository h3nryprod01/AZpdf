import PDFKit
import SwiftUI

struct PDFReaderView: NSViewRepresentable {
    @Bindable var store: DocumentStore

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.document = store.document
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
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

    private func perform(_ action: PDFReaderAction, in view: PDFView) {
        guard let document = view.document else { return }
        let page = view.currentPage ?? document.page(at: store.selectedPageIndex)
        guard let page else { return }
        store.selectedPageIndex = document.index(for: page)

        switch action {
        case .none:
            break
        case .addNote:
            let selectedBounds = view.currentSelection?.bounds(for: page)
            let bounds = (selectedBounds?.isNull == false ? selectedBounds! : page.bounds(for: .cropBox).applying(CGAffineTransform(translationX: 72, y: -100)))
            let noteBounds = CGRect(x: bounds.minX, y: bounds.maxY + 10, width: 32, height: 32)
            let annotation = PDFAnnotation(bounds: noteBounds, forType: .text, withProperties: nil)
            annotation.contents = "Ghi chú AZpdf"
            annotation.color = .systemYellow
            page.addAnnotation(annotation)
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
        case let .freeText(text):
            let selectedBounds = view.currentSelection?.bounds(for: page)
            let cropBox = page.bounds(for: .cropBox)
            let anchor = selectedBounds?.isNull == false ? selectedBounds! : CGRect(x: cropBox.minX + 72, y: cropBox.maxY - 140, width: 260, height: 1)
            let textBounds = CGRect(x: anchor.minX, y: max(cropBox.minY + 20, anchor.minY - 42), width: min(320, cropBox.width - 40), height: 38)
            let annotation = PDFAnnotation(bounds: textBounds, forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.font = .systemFont(ofSize: 14)
            annotation.fontColor = .labelColor
            annotation.color = .clear
            page.addAnnotation(annotation)
            view.clearSelection()
        case let .signature(strokes):
            let cropBox = page.bounds(for: .cropBox)
            let signatureBounds = CGRect(
                x: cropBox.minX + 54,
                y: cropBox.minY + 54,
                width: min(260, cropBox.width - 80),
                height: min(96, cropBox.height - 80)
            )
            let annotation = PDFAnnotation(bounds: signatureBounds, forType: .ink, withProperties: nil)
            annotation.color = .labelColor
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                let path = NSBezierPath()
                path.move(to: signaturePoint(first, in: signatureBounds))
                for point in stroke.points.dropFirst() {
                    path.line(to: signaturePoint(point, in: signatureBounds))
                }
                annotation.add(path)
            }
            page.addAnnotation(annotation)
        }
    }

    private func signaturePoint(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: bounds.minX + point.x / 520 * bounds.width,
            y: bounds.maxY - point.y / 190 * bounds.height
        )
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
