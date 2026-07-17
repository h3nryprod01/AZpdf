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

    /// Uses an existing PDF text layer whenever it is meaningful. This preserves
    /// reading order and avoids losing content on born-digital PDFs; scans fall back
    /// to Vision at high resolution.
    static func recognize(_ page: PDFPage, scale: CGFloat = 3) throws -> PageResult {
        if let text = textLayer(from: page) {
            return PageResult(text: text, source: .textLayer)
        }
        return PageResult(text: try recognize(render(page, scale: scale)), source: .vision)
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
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        let text = normalized((request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n"))
        guard !text.isEmpty else { throw OCRServiceError.noTextFound }
        return text
    }
}
