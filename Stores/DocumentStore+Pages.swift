import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

// Page-level operations: rotate, delete, duplicate, insert, reorder and redact.
extension DocumentStore {
    func rotateCurrentPage() {
        guard let document else { return }
        registerUndoStep()
        let operation = DocumentOperation.rotate(page: selectedPageIndex)
        guard apply(operation, to: document) else { return }
        documentRevision += 1
        isModified = true
        record(operation)
    }

    func deleteCurrentPage() {
        guard let document, document.pageCount > 1 else { return }
        registerUndoStep()
        let operation = DocumentOperation.delete(page: selectedPageIndex)
        guard apply(operation, to: document) else { return }
        selectedPageIndex = min(selectedPageIndex, document.pageCount - 1)
        documentRevision += 1
        isModified = true
        record(operation)
    }

    func duplicateCurrentPage() {
        guard let document else { return }
        registerUndoStep()
        let operation = DocumentOperation.duplicate(page: selectedPageIndex)
        guard apply(operation, to: document) else { return }
        selectedPageIndex += 1
        documentRevision += 1
        isModified = true
        record(operation)
    }

    @MainActor
    func beginInsertPages() {
        guard document != nil, let url = chooseFile(contentTypes: [.pdf]) else { return }
        insertPages(from: url)
    }

    func insertPages(from url: URL) {
        guard let document else { return }
        guard let source = PDFDocument(url: url), source.pageCount > 0 else {
            lastError = "Không thể đọc PDF cần chèn."
            return
        }
        let pages = (0..<source.pageCount).compactMap { source.page(at: $0)?.copy() as? PDFPage }
        guard !pages.isEmpty else { return }
        registerUndoStep()
        let insertionIndex = min(selectedPageIndex + 1, document.pageCount)
        for (offset, page) in pages.enumerated() { document.insert(page, at: insertionIndex + offset) }
        selectedPageIndex = insertionIndex
        documentRevision += 1
        isModified = true
        record(.insertPages(count: pages.count, at: insertionIndex))
    }

    func movePages(from offsets: IndexSet, to destination: Int) {
        guard let document, !offsets.isEmpty else { return }
        registerUndoStep()
        let adjustedDestination = destination - offsets.filter { $0 < destination }.count
        let operation = DocumentOperation.movePages(from: offsets.sorted(), destination: adjustedDestination)
        guard apply(operation, to: document) else { return }
        selectedPageIndex = min(adjustedDestination, document.pageCount - 1)
        documentRevision += 1
        isModified = true
        record(operation)
    }

    func beginRedaction() {
        guard document != nil else { return }
        isRedactionConfirmationPresented = true
    }

    func confirmRedaction() {
        isRedactionConfirmationPresented = false
        sendReaderAction(.redactSelection)
    }

    /// Replaces each affected page with a rasterized copy, so the selected source
    /// content is no longer present in the resulting PDF's text or drawing stream.
    func permanentlyRedact(_ regions: [(pageIndex: Int, bounds: CGRect)]) -> Bool {
        guard let document, !regions.isEmpty else { return false }
        let regionsByPage = Dictionary(grouping: regions, by: \.pageIndex)

        for (pageIndex, pageRegions) in regionsByPage {
            guard let page = document.page(at: pageIndex) else { return false }
            let mediaBox = page.bounds(for: .mediaBox)
            guard mediaBox.width > 0, mediaBox.height > 0 else { return false }

            let image = NSImage(size: mediaBox.size)
            image.lockFocus()
            guard let context = NSGraphicsContext.current?.cgContext else {
                image.unlockFocus()
                return false
            }
            context.saveGState()
            page.draw(with: .mediaBox, to: context)
            context.setFillColor(NSColor.black.cgColor)
            for region in pageRegions {
                context.fill(region.bounds.intersection(mediaBox))
            }
            context.restoreGState()
            image.unlockFocus()

            guard let replacement = PDFPage(image: image) else { return false }
            replacement.rotation = page.rotation
            document.removePage(at: pageIndex)
            document.insert(replacement, at: pageIndex)
        }
        documentRevision += 1
        return true
    }
}
