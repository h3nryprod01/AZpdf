import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

// OCR of a dragged region, the current page or the whole document, plus review
// and export of the recognized text (including a searchable-PDF export).
extension DocumentStore {
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
        placementInstruction = L("Drag on the PDF to select the region to OCR.")
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
            Task {
                let result = await Task.detached(priority: .userInitiated) { Result { try OCRService.recognizeDetailed(image) } }.value
                isOCRProcessing = false
                ocrCompletedPages = 1
                switch result {
                case let .success(recognition):
                    ocrText = L("## Page \(pageIndex + 1) · Vision OCR Region") + "\n" + recognition.text
                    ocrReviews = [Self.makeOCRReview(pageIndex: pageIndex, source: .vision, confidence: recognition.confidence, minConfidence: recognition.minConfidence, lineCount: recognition.lineCount, layoutSummary: recognition.layoutSummary, needsLayoutReview: recognition.needsLayoutReview)]
                case .failure:
                    ocrText = L("## Page \(pageIndex + 1) · Vision OCR Region") + "\n" + L("[No text recognized]")
                    ocrReviews = [OCRPageReview(pageIndex: pageIndex, source: .unavailable, confidence: nil, lineCount: 0, layoutSummary: L("Unavailable"), warning: L("No text recognized in the selected region."))]
                }
            }
        } catch {
            isOCRProcessing = false
            lastError = L("Region OCR failed: \(error.localizedDescription)")
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
            Task {
                var pages: [String] = []
                for (index, textLayer, image) in pageInputs {
                    let pageText: String
                    let review: OCRPageReview
                    if !textLayer.isEmpty {
                        pageText = L("## Page \(index + 1) · \(OCRService.Source.textLayer.displayName)") + "\n" + textLayer
                        review = Self.makeOCRReview(pageIndex: index, source: .textLayer, confidence: nil, lineCount: textLayer.split(separator: "\n").count, layoutSummary: "Text layer PDF", needsLayoutReview: false)
                    } else {
                        let result = await Task.detached(priority: .userInitiated) { Result { try OCRService.recognizeDetailed(image!) } }.value
                        switch result {
                        case let .success(recognition):
                            pageText = L("## Page \(index + 1) · \(OCRService.Source.vision.displayName)") + "\n" + recognition.text
                            review = Self.makeOCRReview(pageIndex: index, source: .vision, confidence: recognition.confidence, minConfidence: recognition.minConfidence, lineCount: recognition.lineCount, layoutSummary: recognition.layoutSummary, needsLayoutReview: recognition.needsLayoutReview)
                        case .failure:
                            pageText = L("## Page \(index + 1)") + "\n" + L("[No text recognized]")
                            review = OCRPageReview(pageIndex: index, source: .unavailable, confidence: nil, lineCount: 0, layoutSummary: L("Unavailable"), warning: L("No text recognized on this page."))
                        }
                    }
                    pages.append(pageText)
                    ocrCompletedPages += 1
                    ocrText = pages.joined(separator: "\n\n")
                    ocrReviews.append(review)
                }
                isOCRProcessing = false
            }
        } catch {
            isOCRProcessing = false
            lastError = L("OCR failed: \(error.localizedDescription)")
        }
    }

    // internal: exercised directly by characterization tests so the warning
    // decision (multi-column / low-confidence / no-lines) is pinned without
    // depending on a live Vision round-trip.
    nonisolated static func makeOCRReview(pageIndex: Int, source: OCRPageReview.Source, confidence: Float?, minConfidence: Float? = nil, lineCount: Int, layoutSummary: String, needsLayoutReview: Bool) -> OCRPageReview {
        let warning: String?
        if needsLayoutReview {
            warning = L("Possible multi-column layout; check the reading order before exporting.")
        } else if source == .vision, let confidence, confidence < 0.85 {
            warning = L("Low confidence; double-check the reading order and characters before exporting.")
        } else if let minConfidence, minConfidence < 0.5 {
            warning = L("At least one line was recognized with low confidence; re-check this page before exporting.")
        } else if lineCount == 0 {
            warning = L("No reviewable lines of text found.")
        } else {
            warning = nil
        }
        return OCRPageReview(pageIndex: pageIndex, source: source, confidence: confidence, lineCount: lineCount, layoutSummary: layoutSummary, warning: warning)
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
            lastError = L("Could not export the OCR text: \(error.localizedDescription)")
        }
    }

    @MainActor
    func exportSearchablePDF() {
        guard let documentData = document?.dataRepresentation(), !ocrText.isEmpty, !isSearchablePDFExporting else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title)-searchable.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        performSearchablePDFExport(documentData: documentData, to: url)
    }

    /// Phần việc sau khi người dùng đã chọn nơi lưu.
    ///
    /// Tách ra khỏi `exportSearchablePDF()` vì phần trên bị chặn bởi `panel.runModal()` —
    /// NSSavePanel không chạy được headless, nên toàn bộ nhánh này trước đây không có cách
    /// nào viết test đặc tính. Đo được: mutation trên vùng này sống sót 100 %.
    func performSearchablePDFExport(documentData: Data, to url: URL) {
        isSearchablePDFExporting = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try OCRMyPDFService.createSearchablePDF(documentData: documentData) }
            }.value
            isSearchablePDFExporting = false
            switch result {
            case let .success(data):
                do {
                    try data.write(to: url, options: .atomic)
                    isOCRSheetPresented = false
                    open(url)
                } catch {
                    lastError = L("Could not save the searchable PDF: \(error.localizedDescription)")
                }
            case let .failure(error):
                lastError = error.localizedDescription
            }
        }
    }
}
