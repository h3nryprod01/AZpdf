import AppKit
import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

@Observable
final class DocumentStore {
    private let engine = PDFKitDocumentEngine()
    private let recentDocumentsKey = "recentDocumentPaths"
    private struct DocumentSnapshot {
        let data: Data
        let selectedPageIndex: Int
    }

    var document: PDFDocument?
    var fileURL: URL?
    var selectedPageIndex = 0
    var zoomScale: CGFloat = 1
    var isAutoScale = true
    var isInsertImporterPresented = false
    var isImageImporterPresented = false
    var isExportPresented = false
    var isCurrentPageExporterPresented = false
    var isPasswordPromptPresented = false
    var isPasswordProtectSheetPresented = false
    var isTextAnnotationSheetPresented = false
    var isSignatureSheetPresented = false
    var isCertificateSigningSheetPresented = false
    var isRedactionConfirmationPresented = false
    var searchText = ""
    var searchResultCount = 0
    var searchResultIndex = 0
    var searchNavigationID = 0
    var searchDirection = 1
    var lastError: String?
    var currentPageExportData: Data?
    var password = ""
    var exportPassword = ""
    var draftTextAnnotation = ""
    var draftSignatureStrokes: [SignatureStroke] = []
    var certificateSigningIdentities: [CertificateIdentity] = []
    var selectedCertificateIdentityID = ""
    var readerAction: PDFReaderAction = .none
    var readerActionID = 0
    var documentRevision = 0
    var isModified = false
    var recentDocumentPaths: [String]
    private var undoStack: [DocumentSnapshot] = []
    private var redoStack: [DocumentSnapshot] = []
    private(set) var lastOperation: DocumentOperation?

    init() {
        recentDocumentPaths = UserDefaults.standard.stringArray(forKey: recentDocumentsKey) ?? []
    }

    var title: String { fileURL?.deletingPathExtension().lastPathComponent ?? "Chưa mở tài liệu" }
    var pageCount: Int { document?.pageCount ?? 0 }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var canGoToPreviousPage: Bool { selectedPageIndex > 0 }
    var canGoToNextPage: Bool { selectedPageIndex + 1 < pageCount }
    var windowTitle: String { isModified ? "\(title) — Đã chỉnh sửa" : title }
    var recentDocumentURLs: [URL] { recentDocumentPaths.map(URL.init(fileURLWithPath:)) }
    var formFieldCount: Int {
        guard let document else { return 0 }
        return (0..<document.pageCount).reduce(into: 0) { count, index in
            count += document.page(at: index)?.annotations.filter {
                $0.type?.caseInsensitiveCompare(PDFAnnotationSubtype.widget.rawValue) == .orderedSame
                    || $0.widgetFieldType == PDFAnnotationWidgetSubtype.text
                    || $0.widgetFieldType == PDFAnnotationWidgetSubtype.button
                    || $0.widgetFieldType == PDFAnnotationWidgetSubtype.choice
                    || $0.widgetFieldType == PDFAnnotationWidgetSubtype.signature
            }.count ?? 0
        }
    }

    func open(_ url: URL) {
        guard let pdf = PDFDocument(url: url) else {
            lastError = "Không thể đọc tệp PDF này."
            return
        }
        document = pdf
        fileURL = url
        selectedPageIndex = 0
        zoomScale = 1
        isAutoScale = true
        documentRevision += 1
        undoStack.removeAll()
        redoStack.removeAll()
        lastOperation = nil
        isPasswordPromptPresented = pdf.isLocked
        isModified = false
        addToRecentDocuments(url)
    }

    @MainActor
    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func unlockDocument() {
        guard let document else { return }
        guard document.unlock(withPassword: password) else {
            lastError = "Mật khẩu không đúng. Vui lòng thử lại."
            return
        }
        password = ""
        isPasswordPromptPresented = false
        documentRevision += 1
    }

    func save() {
        guard let document, let fileURL else { return }
        guard document.write(to: fileURL) else { lastError = "Không thể lưu thay đổi."; return }
        isModified = false
    }

    func openRecentDocument(_ url: URL) {
        open(url)
    }

    func removeRecentDocument(_ url: URL) {
        recentDocumentPaths.removeAll { $0 == url.path }
        persistRecentDocuments()
    }

    func goToPreviousPage() {
        guard canGoToPreviousPage else { return }
        selectedPageIndex -= 1
    }

    func goToNextPage() {
        guard canGoToNextPage else { return }
        selectedPageIndex += 1
    }

    func goToPreviousSearchResult() {
        guard searchResultCount > 0 else { return }
        searchDirection = -1
        searchNavigationID += 1
    }

    func goToNextSearchResult() {
        guard searchResultCount > 0 else { return }
        searchDirection = 1
        searchNavigationID += 1
    }

    func zoomOut() {
        switchToManualZoomIfNeeded()
        zoomScale = max(0.5, zoomScale - 0.1)
    }

    func zoomIn() {
        switchToManualZoomIfNeeded()
        zoomScale = min(4, zoomScale + 0.1)
    }

    func fitPage() {
        isAutoScale = true
    }

    func export(to url: URL) {
        guard let document else { return }
        guard document.write(to: url) else { lastError = "Không thể xuất PDF."; return }
    }

    func beginPasswordProtectedExport() {
        guard document != nil else { return }
        exportPassword = ""
        isPasswordProtectSheetPresented = true
    }

    @MainActor func savePasswordProtectedExport() {
        let password = exportPassword
        guard !password.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title)-bao-ve.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard writeProtectedCopy(to: url, password: password) else {
            lastError = "Không thể tạo PDF được bảo vệ."
            return
        }
        exportPassword = ""
        isPasswordProtectSheetPresented = false
    }

    func writeProtectedCopy(to url: URL, password: String) -> Bool {
        guard let document, !password.isEmpty else { return false }
        return document.write(to: url, withOptions: [
            .userPasswordOption: password,
            .ownerPasswordOption: password
        ])
    }

    func prepareCurrentPageExport() {
        guard let page = document?.page(at: selectedPageIndex), let copy = page.copy() as? PDFPage else { return }
        let extracted = PDFDocument()
        extracted.insert(copy, at: 0)
        currentPageExportData = extracted.dataRepresentation()
        isCurrentPageExporterPresented = currentPageExportData != nil
    }

    func addNote() {
        sendReaderAction(.addNote)
    }

    func beginTextAnnotation() {
        guard document != nil else { return }
        draftTextAnnotation = ""
        isTextAnnotationSheetPresented = true
    }

    func addTextAnnotation() {
        let text = draftTextAnnotation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isTextAnnotationSheetPresented = false
        draftTextAnnotation = ""
        sendReaderAction(.freeText(text))
    }

    func highlightSelection() {
        sendReaderAction(.highlightSelection)
    }

    func beginSignature() {
        guard document != nil else { return }
        draftSignatureStrokes = []
        isSignatureSheetPresented = true
    }

    func addSignature() {
        let strokes = draftSignatureStrokes.filter { $0.points.count > 1 }
        guard !strokes.isEmpty else {
            lastError = "Hãy vẽ chữ ký trước khi chèn."
            return
        }
        isSignatureSheetPresented = false
        draftSignatureStrokes = []
        sendReaderAction(.signature(strokes))
    }

    func beginCertificateSigning() {
        guard document != nil else { return }
        do {
            certificateSigningIdentities = try CertificateSigningService.availableIdentities()
            selectedCertificateIdentityID = certificateSigningIdentities.first?.id ?? ""
            isCertificateSigningSheetPresented = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func exportDetachedCertificateSignature() {
        guard let documentData = document?.dataRepresentation(),
              let identity = certificateSigningIdentities.first(where: { $0.id == selectedCertificateIdentityID }) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "\(title).pdf.p7s"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let signature = try CertificateSigningService.detachedSignature(for: documentData, identity: identity)
            try signature.write(to: url, options: .atomic)
            isCertificateSigningSheetPresented = false
        } catch {
            lastError = "Không thể tạo chữ ký số: \(error.localizedDescription)"
        }
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

    func record(_ operation: DocumentOperation) {
        lastOperation = operation
    }

    func rotateCurrentPage() {
        guard let document else { return }
        registerUndoStep()
        let operation = DocumentOperation.rotate(page: selectedPageIndex)
        guard apply(operation, to: document) else { return }
        documentRevision += 1
        isModified = true
        lastOperation = operation
    }

    func deleteCurrentPage() {
        guard let document, document.pageCount > 1 else { return }
        registerUndoStep()
        let operation = DocumentOperation.delete(page: selectedPageIndex)
        guard apply(operation, to: document) else { return }
        selectedPageIndex = min(selectedPageIndex, document.pageCount - 1)
        documentRevision += 1
        isModified = true
        lastOperation = operation
    }

    func deleteAnnotation(at index: Int) {
        guard let page = document?.page(at: selectedPageIndex), page.annotations.indices.contains(index) else { return }
        registerUndoStep()
        page.removeAnnotation(page.annotations[index])
        documentRevision += 1
        isModified = true
    }

    func duplicateCurrentPage() {
        guard let document else { return }
        registerUndoStep()
        let operation = DocumentOperation.duplicate(page: selectedPageIndex)
        guard apply(operation, to: document) else { return }
        selectedPageIndex += 1
        documentRevision += 1
        isModified = true
        lastOperation = operation
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
        lastOperation = .insertPages(count: pages.count, at: insertionIndex)
    }

    func insertImage(from url: URL) {
        guard let document, let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else {
            lastError = "Không thể đọc ảnh để chèn."
            return
        }
        registerUndoStep()
        let insertionIndex = min(selectedPageIndex + 1, document.pageCount)
        document.insert(page, at: insertionIndex)
        selectedPageIndex = insertionIndex
        documentRevision += 1
        isModified = true
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
        lastOperation = operation
    }

    private func sendReaderAction(_ action: PDFReaderAction) {
        guard document != nil else { return }
        registerUndoStep()
        readerAction = action
        readerActionID += 1
        isModified = true
    }

    private func apply(_ operation: DocumentOperation, to document: PDFDocument) -> Bool {
        do {
            try engine.apply(operation, to: document)
            return true
        } catch {
            lastError = "Không thể thực hiện thao tác PDF này."
            return false
        }
    }

    func undo() {
        guard let snapshot = undoStack.popLast(), let current = currentSnapshot else { return }
        redoStack.append(current)
        restore(snapshot)
        isModified = true
    }

    func redo() {
        guard let snapshot = redoStack.popLast(), let current = currentSnapshot else { return }
        undoStack.append(current)
        restore(snapshot)
        isModified = true
    }

    private var currentSnapshot: DocumentSnapshot? {
        guard let data = document?.dataRepresentation() else { return nil }
        return DocumentSnapshot(data: data, selectedPageIndex: selectedPageIndex)
    }

    private func registerUndoStep() {
        guard let snapshot = currentSnapshot else { return }
        undoStack.append(snapshot)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func restore(_ snapshot: DocumentSnapshot) {
        document = PDFDocument(data: snapshot.data)
        selectedPageIndex = min(snapshot.selectedPageIndex, max(0, (document?.pageCount ?? 1) - 1))
        documentRevision += 1
    }

    private func addToRecentDocuments(_ url: URL) {
        recentDocumentPaths.removeAll { $0 == url.path }
        recentDocumentPaths.insert(url.path, at: 0)
        recentDocumentPaths = Array(recentDocumentPaths.prefix(8))
        persistRecentDocuments()
    }

    private func persistRecentDocuments() {
        UserDefaults.standard.set(recentDocumentPaths, forKey: recentDocumentsKey)
    }

    private func switchToManualZoomIfNeeded() {
        guard isAutoScale else { return }
        isAutoScale = false
        zoomScale = 1
    }
}
