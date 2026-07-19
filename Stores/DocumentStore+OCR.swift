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
                        self.ocrReviews = [Self.makeOCRReview(pageIndex: pageIndex, source: .vision, confidence: recognition.confidence, lineCount: recognition.lineCount, layoutSummary: recognition.layoutSummary, needsLayoutReview: recognition.needsLayoutReview)]
                    case .failure:
                        self.ocrText = "## Trang \(pageIndex + 1) · vùng OCR Vision\n[Không nhận dạng được văn bản]"
                        self.ocrReviews = [OCRPageReview(pageIndex: pageIndex, source: .unavailable, confidence: nil, lineCount: 0, layoutSummary: "Không xác định", warning: "Không nhận dạng được văn bản trong vùng đã chọn.")]
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
                        review = Self.makeOCRReview(pageIndex: index, source: .textLayer, confidence: nil, lineCount: textLayer.split(separator: "\n").count, layoutSummary: "Text layer PDF", needsLayoutReview: false)
                    } else {
                        let result = Result { try OCRService.recognizeDetailed(image!) }
                        switch result {
                        case let .success(recognition):
                            pageText = "## Trang \(index + 1) · \(OCRService.Source.vision.displayName)\n\(recognition.text)"
                            review = Self.makeOCRReview(pageIndex: index, source: .vision, confidence: recognition.confidence, lineCount: recognition.lineCount, layoutSummary: recognition.layoutSummary, needsLayoutReview: recognition.needsLayoutReview)
                        case .failure:
                            pageText = "## Trang \(index + 1)\n[Không nhận dạng được văn bản]"
                            review = OCRPageReview(pageIndex: index, source: .unavailable, confidence: nil, lineCount: 0, layoutSummary: "Không xác định", warning: "Không nhận dạng được văn bản trên trang này.")
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

    nonisolated private static func makeOCRReview(pageIndex: Int, source: OCRPageReview.Source, confidence: Float?, lineCount: Int, layoutSummary: String, needsLayoutReview: Bool) -> OCRPageReview {
        let warning: String?
        if needsLayoutReview {
            warning = "Nghi vấn nhiều cột; kiểm tra thứ tự đọc trước khi xuất."
        } else if source == .vision, let confidence, confidence < 0.85 {
            warning = "Độ tin cậy thấp; kiểm tra lại thứ tự đọc và ký tự trước khi xuất."
        } else if lineCount == 0 {
            warning = "Không tìm thấy dòng văn bản có thể kiểm tra."
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
}
