import AppKit
import PDFKit
import Vision

enum OCRServiceError: LocalizedError {
    case unableToRenderPage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .unableToRenderPage: "Không thể tạo ảnh từ trang PDF để OCR."
        case .noTextFound: "Không nhận dạng được văn bản trên trang này."
        }
    }
}

enum OCRService {
    enum Source: String, Sendable {
        case textLayer
        case vision

        var displayName: String {
            switch self {
            case .textLayer: "text layer PDF"
            case .vision: "OCR Vision"
            }
        }
    }

    struct PageResult: Sendable {
        let text: String
        let source: Source
        let confidence: Float?
        let lineCount: Int
        let layoutSummary: String
        let needsLayoutReview: Bool
    }

    struct Recognition: Sendable {
        let text: String
        let confidence: Float
        let lineCount: Int
        let layoutSummary: String
        let needsLayoutReview: Bool
    }

    /// Renders locally before Vision receives the pixels; no document data leaves the Mac.
    static func render(_ page: PDFPage, scale: CGFloat = 2) throws -> CGImage {
        let bounds = page.bounds(for: .cropBox)
        guard bounds.width > 0, bounds.height > 0 else { throw OCRServiceError.unableToRenderPage }
        let image = NSImage(size: CGSize(width: bounds.width * scale, height: bounds.height * scale))
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw OCRServiceError.unableToRenderPage
        }
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .cropBox, to: context)
        image.unlockFocus()
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRServiceError.unableToRenderPage
        }
        return cgImage
    }

    static func render(_ page: PDFPage, crop: CGRect, scale: CGFloat = 2) throws -> CGImage {
        let pageBounds = page.bounds(for: .cropBox)
        let bounds = crop.intersection(pageBounds)
        guard !bounds.isNull, !bounds.isEmpty else { throw OCRServiceError.unableToRenderPage }
        let image = NSImage(size: CGSize(width: bounds.width * scale, height: bounds.height * scale))
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw OCRServiceError.unableToRenderPage
        }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .cropBox, to: context)
        image.unlockFocus()
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRServiceError.unableToRenderPage
        }
        return cgImage
    }

    /// Uses an existing PDF text layer whenever it is meaningful. This preserves
    /// reading order and avoids losing content on born-digital PDFs; scans fall back
    /// to Vision at high resolution.
    static func recognize(_ page: PDFPage, scale: CGFloat = 3) throws -> PageResult {
        if let text = textLayer(from: page) {
            return PageResult(text: text, source: .textLayer, confidence: nil, lineCount: text.split(separator: "\n").count, layoutSummary: "Text layer PDF", needsLayoutReview: false)
        }
        let recognition = try recognizeDetailed(render(page, scale: scale))
        return PageResult(text: recognition.text, source: .vision, confidence: recognition.confidence, lineCount: recognition.lineCount, layoutSummary: recognition.layoutSummary, needsLayoutReview: recognition.needsLayoutReview)
    }

    static func textLayer(from page: PDFPage) -> String? {
        let text = normalized(page.string ?? "")
        // A handful of characters is often a page label or an artifact on a scan,
        // not a usable text layer. Let Vision handle those pages instead.
        return text.count >= 24 ? text : nil
    }

    static func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func recognize(_ image: CGImage) throws -> String {
        try recognizeDetailed(image).text
    }

    /// Keeps the extracted text and a confidence signal separate so the UI can
    /// make uncertain pages explicit instead of presenting OCR as definitive.
    static func recognizeDetailed(_ image: CGImage) throws -> Recognition {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        let observations = request.results ?? []
        let candidates = observations.compactMap { $0.topCandidates(1).first }
        let text = normalized(candidates.map(\.string).joined(separator: "\n"))
        guard !text.isEmpty else { throw OCRServiceError.noTextFound }
        let confidence = candidates.map(\.confidence).reduce(0, +) / Float(candidates.count)
        let leftColumnLines = observations.filter { $0.boundingBox.midX < 0.45 }.count
        let rightColumnLines = observations.filter { $0.boundingBox.midX > 0.55 }.count
        let hasMultipleColumns = leftColumnLines >= 3 && rightColumnLines >= 3
        let layoutSummary = hasMultipleColumns ? "Nghi vấn bố cục đa cột" : "Bố cục một cột/đơn giản"
        return Recognition(text: text, confidence: confidence, lineCount: candidates.count, layoutSummary: layoutSummary, needsLayoutReview: hasMultipleColumns)
    }
}
