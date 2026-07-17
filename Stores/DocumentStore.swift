import AppKit
import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

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
    private var isReplacingSelectedImage = false
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
    var padesVerificationMessage = ""
    var ocrText = ""
    var ocrReviews: [OCRPageReview] = []
    var conformanceReport: PDFConformanceReport?
    var conformanceError: String?
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

    @MainActor
    func saveAs() {
        guard let document else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard document.write(to: url) else { lastError = "Không thể lưu bản sao PDF."; return }
        fileURL = url
        isModified = false
        addToRecentDocuments(url)
    }

    func selectAnnotation(_ annotation: PDFAnnotation?, pageIndex: Int?) {
        selectedAnnotation = annotation
        selectedAnnotationPageIndex = pageIndex
        selectedAnnotationText = annotation?.contents ?? ""
        selectedAnnotationFontSize = Double(annotation?.font?.pointSize ?? 14)
        selectedAnnotationColor = annotation?.fontColor ?? annotation?.color ?? .labelColor
        selectedAnnotationWidth = Double(annotation?.bounds.width ?? 0)
        selectedAnnotationHeight = Double(annotation?.bounds.height ?? 0)
        annotationSelectionID += 1
    }

    func beginAnnotationMove() {
        registerUndoStep()
    }

    func finishAnnotationMove() {
        guard selectedAnnotation != nil else { return }
        isModified = true
    }

    func updateSelectedFreeText() {
        guard let annotation = selectedAnnotation,
              annotation.isAZpdfFreeText else { return }
        registerUndoStep()
        annotation.contents = selectedAnnotationText
        annotation.font = .systemFont(ofSize: selectedAnnotationFontSize)
        annotation.fontColor = selectedAnnotationColor
        annotation.color = .clear
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func updateSelectedNote() {
        guard let annotation = selectedAnnotation else { return }
        registerUndoStep()
        annotation.contents = selectedAnnotationText
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func updateSelectedImageSize() {
        guard let annotation = selectedAnnotation,
              annotation.isAZpdfImage else { return }
        registerUndoStep()
        annotation.bounds.size = CGSize(
            width: max(24, selectedAnnotationWidth),
            height: max(24, selectedAnnotationHeight)
        )
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func beginImageInsertion() {
        isReplacingSelectedImage = false
        showImageOpenPanel()
    }

    func beginReplaceSelectedImage() {
        guard selectedAnnotation is EditableImageAnnotation else { return }
        isReplacingSelectedImage = true
        showImageOpenPanel()
    }

    @MainActor
    private func showImageOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else {
            isReplacingSelectedImage = false
            return
        }
        importImage(from: url)
    }

    /// Provides a keyboard and VoiceOver-accessible alternative to dragging an annotation.
    func moveSelectedAnnotation(horizontal: CGFloat, vertical: CGFloat) {
        guard let annotation = selectedAnnotation,
              let document,
              let pageIndex = selectedAnnotationPageIndex,
              let page = document.page(at: pageIndex) else { return }
        registerUndoStep()
        let cropBox = page.bounds(for: .cropBox)
        let candidate = annotation.bounds.offsetBy(dx: horizontal, dy: vertical)
        annotation.bounds = CGRect(
            x: min(max(candidate.minX, cropBox.minX), cropBox.maxX - candidate.width),
            y: min(max(candidate.minY, cropBox.minY), cropBox.maxY - candidate.height),
            width: candidate.width,
            height: candidate.height
        )
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
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

    @MainActor
    func beginOCRCurrentPage() {
        beginOCR(pageIndices: [selectedPageIndex])
    }

    @MainActor
    func beginOCRDocument() {
        guard let document else { return }
        beginOCR(pageIndices: Array(0..<document.pageCount))
    }

    func beginOCRRegionSelection() {
        guard document != nil else { return }
        placementInstruction = "Kéo trên PDF để chọn vùng cần OCR."
        sendReaderAction(.ocrRegion, recordsUndo: false)
    }

    func beginOCRRegion(pageIndex: Int, bounds: CGRect) {
        guard let page = document?.page(at: pageIndex), !isOCRProcessing else { return }
        isOCRSheetPresented = true
        isOCRProcessing = true
        ocrText = ""
        ocrReviews = []
        ocrPageIndex = pageIndex
        ocrCompletedPages = 0
        ocrTotalPages = 1
        placementInstruction = nil
        do {
            let image = try OCRService.render(page, crop: bounds, scale: 3)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = Result { try OCRService.recognizeDetailed(image) }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isOCRProcessing = false
                    self.ocrCompletedPages = 1
                    switch result {
                    case let .success(recognition):
                        self.ocrText = "## Trang \(pageIndex + 1) · vùng OCR Vision\n\(recognition.text)"
                        self.ocrReviews = [Self.makeOCRReview(pageIndex: pageIndex, source: .vision, confidence: recognition.confidence, lineCount: recognition.lineCount)]
                    case .failure:
                        self.ocrText = "## Trang \(pageIndex + 1) · vùng OCR Vision\n[Không nhận dạng được văn bản]"
                        self.ocrReviews = [OCRPageReview(pageIndex: pageIndex, source: .unavailable, confidence: nil, lineCount: 0, warning: "Không nhận dạng được văn bản trong vùng đã chọn.")]
                    }
                }
            }
        } catch {
            isOCRProcessing = false
            lastError = "OCR vùng thất bại: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func beginOCR(pageIndices: [Int]) {
        guard let document, !pageIndices.isEmpty else { return }
        isOCRSheetPresented = true
        isOCRProcessing = true
        ocrText = ""
        ocrReviews = []
        ocrPageIndex = pageIndices.first ?? selectedPageIndex
        ocrCompletedPages = 0
        ocrTotalPages = pageIndices.count
        do {
            let pageInputs = try pageIndices.compactMap { index -> (Int, String, CGImage?)? in
                guard let page = document.page(at: index) else { return nil }
                if let text = OCRService.textLayer(from: page) { return (index, text, nil) }
                return (index, "", try OCRService.render(page, scale: 3))
            }
            guard !pageInputs.isEmpty else {
                isOCRProcessing = false
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var pages: [String] = []
                for (index, textLayer, image) in pageInputs {
                    let pageText: String
                    let review: OCRPageReview
                    if !textLayer.isEmpty {
                        pageText = "## Trang \(index + 1) · \(OCRService.Source.textLayer.displayName)\n\(textLayer)"
                        review = Self.makeOCRReview(pageIndex: index, source: .textLayer, confidence: nil, lineCount: textLayer.split(separator: "\n").count)
                    } else {
                        let result = Result { try OCRService.recognizeDetailed(image!) }
                        switch result {
                        case let .success(recognition):
                            pageText = "## Trang \(index + 1) · \(OCRService.Source.vision.displayName)\n\(recognition.text)"
                            review = Self.makeOCRReview(pageIndex: index, source: .vision, confidence: recognition.confidence, lineCount: recognition.lineCount)
                        case .failure:
                            pageText = "## Trang \(index + 1)\n[Không nhận dạng được văn bản]"
                            review = OCRPageReview(pageIndex: index, source: .unavailable, confidence: nil, lineCount: 0, warning: "Không nhận dạng được văn bản trên trang này.")
                        }
                    }
                    pages.append(pageText)
                    let previewText = pages.joined(separator: "\n\n")
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.ocrCompletedPages += 1
                        self.ocrText = previewText
                        self.ocrReviews.append(review)
                    }
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isOCRProcessing = false
                }
            }
        } catch {
            isOCRProcessing = false
            lastError = "OCR thất bại: \(error.localizedDescription)"
        }
    }

    nonisolated private static func makeOCRReview(pageIndex: Int, source: OCRPageReview.Source, confidence: Float?, lineCount: Int) -> OCRPageReview {
        let warning: String?
        if source == .vision, let confidence, confidence < 0.85 {
            warning = "Độ tin cậy thấp; kiểm tra lại thứ tự đọc và ký tự trước khi xuất."
        } else if lineCount == 0 {
            warning = "Không tìm thấy dòng văn bản có thể kiểm tra."
        } else {
            warning = nil
        }
        return OCRPageReview(pageIndex: pageIndex, source: source, confidence: confidence, lineCount: lineCount, warning: warning)
    }

    @MainActor
    func copyOCRText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ocrText, forType: .string)
    }

    @MainActor
    func exportOCRText() {
        guard !ocrText.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(title)-trang-\(ocrPageIndex + 1)-ocr.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ocrText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            lastError = "Không thể xuất văn bản OCR: \(error.localizedDescription)"
        }
    }

    @MainActor
    func exportSearchablePDF() {
        guard let documentData = document?.dataRepresentation(), !ocrText.isEmpty, !isSearchablePDFExporting else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title)-searchable.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isSearchablePDFExporting = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try OCRMyPDFService.createSearchablePDF(documentData: documentData) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSearchablePDFExporting = false
                switch result {
                case let .success(data):
                    do {
                        try data.write(to: url, options: .atomic)
                        self.isOCRSheetPresented = false
                        self.open(url)
                    } catch {
                        self.lastError = "Không thể lưu PDF có lớp chữ: \(error.localizedDescription)"
                    }
                case let .failure(error):
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func beginConformanceCheck() {
        guard document != nil else { return }
        conformanceReport = nil
        conformanceError = nil
        isConformanceSheetPresented = true
    }

    func checkConformance(_ profile: PDFConformanceProfile) {
        guard let data = document?.dataRepresentation(), !isConformanceChecking else { return }
        isConformanceChecking = true
        conformanceError = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try PDFConformanceService.validate(data, profile: profile) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isConformanceChecking = false
                switch result {
                case let .success(report): self.conformanceReport = report
                case let .failure(error): self.conformanceError = error.localizedDescription
                }
            }
        }
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
        placementInstruction = "Nhấp vào PDF để đặt hộp chữ."
        sendReaderAction(.freeText(text), recordsUndo: false)
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
        placementInstruction = "Nhấp vào PDF để đặt chữ ký."
        sendReaderAction(.signature(strokes), recordsUndo: false)
    }

    func cancelPlacement() {
        placementInstruction = nil
        readerAction = .none
        readerActionID += 1
    }

    func prepareAnnotationPlacement() {
        registerUndoStep()
    }

    func finishAnnotationPlacement(_ operation: DocumentOperation) {
        placementInstruction = nil
        record(operation)
        isModified = true
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

    func beginCertificateSignatureVerification() {
        guard document != nil else { return }
        isCertificateSignatureImporterPresented = true
    }

    func beginPAdESSigning() {
        guard document != nil else { return }
        isPAdESSigningSheetPresented = true
    }

    func choosePAdESCertificate() {
        isPAdESCertificateImporterPresented = true
    }

    func selectPAdESCertificate(at url: URL) {
        do {
            padesPKCS12Data = try Data(contentsOf: url)
            padesCertificateName = url.lastPathComponent
        } catch {
            lastError = "Không thể đọc PKCS#12: \(error.localizedDescription)"
        }
    }

    @MainActor
    func exportPAdESSignedPDF() {
        guard let documentData = document?.dataRepresentation(), let pkcs12Data = padesPKCS12Data else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title)-signed.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        defer {
            padesPassword = ""
            padesPKCS12Data = nil
            padesCertificateName = ""
        }
        do {
            let signed = try PAdESSigningService.sign(
                documentData: documentData,
                pkcs12Data: pkcs12Data,
                password: padesPassword
            )
            try signed.write(to: url, options: .atomic)
            isPAdESSigningSheetPresented = false
            open(url)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func verifyPAdESSignatures() {
        guard let documentData = document?.dataRepresentation() else { return }
        do {
            padesVerificationMessage = try PAdESSigningService.verify(documentData: documentData).summary
        } catch {
            padesVerificationMessage = "Không thể xác minh PAdES: \(error.localizedDescription)"
        }
        isPAdESVerificationResultPresented = true
    }

    func verifyDetachedCertificateSignature(at url: URL) {
        guard let documentData = document?.dataRepresentation() else { return }
        do {
            let signature = try Data(contentsOf: url)
            certificateVerificationMessage = try CertificateSigningService
                .verifyDetachedSignature(signature, documentData: documentData)
                .summary
        } catch {
            certificateVerificationMessage = "Không thể xác minh chữ ký: \(error.localizedDescription)"
        }
        isCertificateVerificationResultPresented = true
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

    func importImage(from url: URL) {
        if isReplacingSelectedImage {
            isReplacingSelectedImage = false
            replaceSelectedImage(from: url)
        } else {
            insertImage(from: url)
        }
    }

    func insertImage(from url: URL) {
        guard document != nil, NSImage(contentsOf: url) != nil else {
            lastError = "Không thể đọc ảnh để chèn."
            return
        }
        do {
            let imageURL = try cachedImageURL(from: url)
            placementInstruction = "Nhấp vào PDF để đặt ảnh. Sau đó kéo ảnh để di chuyển hoặc chọn ảnh để đổi kích thước."
            sendReaderAction(.image(imageURL), recordsUndo: false)
        } catch {
            lastError = "Không thể chuẩn bị ảnh để chèn: \(error.localizedDescription)"
        }
    }

    func insertImageOverlay(from imageURL: URL, pageIndex: Int, bounds: CGRect) {
        guard let page = document?.page(at: pageIndex), let image = NSImage(contentsOf: imageURL) else {
            lastError = "Không thể đọc ảnh để chèn."
            return
        }
        registerUndoStep()
        let annotation = EditableImageAnnotation(image: image, bounds: bounds)
        page.addAnnotation(annotation)
        selectAnnotation(annotation, pageIndex: pageIndex)
        documentRevision += 1
        placementInstruction = nil
        isModified = true
        lastOperation = .addAnnotation(kind: .image, page: pageIndex)
    }

    private func replaceSelectedImage(from url: URL) {
        guard let annotation = selectedAnnotation as? EditableImageAnnotation,
              let image = NSImage(contentsOf: url) else {
            lastError = "Không thể đọc ảnh thay thế."
            return
        }
        registerUndoStep()
        annotation.replaceImage(image)
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

    private func sendReaderAction(_ action: PDFReaderAction, recordsUndo: Bool = true) {
        guard document != nil else { return }
        if recordsUndo { registerUndoStep() }
        readerAction = action
        readerActionID += 1
        if recordsUndo { isModified = true }
    }

    private func cachedImageURL(from url: URL) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "AZpdf-Images", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        let destination = directory.appending(path: "\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
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
