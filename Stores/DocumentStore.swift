import AppKit
import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

// Feature actions live in DocumentStore+*.swift extensions (FileIO, Annotations,
// Pages, Navigation, OCR, Signing, Conformance). This file owns the observable
// state and the shared plumbing those extensions build on. Helpers used across
// those files are `internal` rather than `private` so the extensions can reach
// them; everything only touched here stays `private`.
@MainActor @Observable
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
    var isReplacingSelectedImage = false // internal for DocumentStore+Annotations
    var isExportPresented = false
    var isCurrentPageExporterPresented = false
    var isPasswordPromptPresented = false
    var isPasswordProtectSheetPresented = false
    var isTextAnnotationSheetPresented = false
    var isSignatureSheetPresented = false
    var isCertificateSigningSheetPresented = false
    var isCertificateSignatureImporterPresented = false
    var isCertificateVerificationResultPresented = false
    var isPAdESSigningSheetPresented = false
    var isPAdESCertificateImporterPresented = false
    var isPAdESVerificationResultPresented = false
    var isOCRSheetPresented = false
    var isConformanceSheetPresented = false
    var isDocumentPropertiesSheetPresented = false
    // Find bar and inspector live on the store, not in View @State, so the
    // menu commands (⌘F, ⌘I) can reach them without depending on the toolbar.
    var isFindBarPresented = false
    var isInspectorPresented = false
    var isConformanceChecking = false
    var isOCRProcessing = false
    var isSearchablePDFExporting = false
    var ocrCompletedPages = 0
    var ocrTotalPages = 0
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
    var placementInstruction: String?
    var certificateSigningIdentities: [CertificateIdentity] = []
    var selectedCertificateIdentityID = ""
    var certificateVerificationMessage = ""
    var padesPKCS12Data: Data?
    var padesCertificateName = ""
    var padesPassword = ""
    var padesProfile: PAdESProfile = .baselineB
    var padesTimestampURL = ""
    var padesVerificationMessage = ""
    var ocrText = ""
    var ocrReviews: [OCRPageReview] = []
    var conformanceReport: PDFConformanceReport?
    var conformanceError: String?
    var documentMetadataTitle = ""
    var documentMetadataAuthor = ""
    var documentMetadataSubject = ""
    var documentMetadataKeywords = ""
    var ocrPageIndex = 0
    var readerAction: PDFReaderAction = .none
    var readerActionID = 0
    var documentRevision = 0
    var isModified = false
    var selectedAnnotation: PDFAnnotation?
    var selectedAnnotationPageIndex: Int?
    var selectedAnnotationText = ""
    var selectedAnnotationFontSize: Double = 14
    var selectedAnnotationColor = NSColor.labelColor
    var selectedAnnotationWidth: Double = 0
    var selectedAnnotationHeight: Double = 0
    var annotationSelectionID = 0
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

    // MARK: - Shared plumbing

    func record(_ operation: DocumentOperation) {
        lastOperation = operation
    }

    func sendReaderAction(_ action: PDFReaderAction, recordsUndo: Bool = true) {
        guard document != nil else { return }
        if recordsUndo { registerUndoStep() }
        readerAction = action
        readerActionID += 1
        if recordsUndo { isModified = true }
    }

    func apply(_ operation: DocumentOperation, to document: PDFDocument) -> Bool {
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

    func registerUndoStep() {
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

    func addToRecentDocuments(_ url: URL) {
        recentDocumentPaths.removeAll { $0 == url.path }
        recentDocumentPaths.insert(url.path, at: 0)
        recentDocumentPaths = Array(recentDocumentPaths.prefix(8))
        persistRecentDocuments()
    }

    func persistRecentDocuments() {
        UserDefaults.standard.set(recentDocumentPaths, forKey: recentDocumentsKey)
    }
}
