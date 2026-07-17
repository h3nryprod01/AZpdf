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

    static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["vi-VN", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw OCRServiceError.noTextFound }
        return text
    }
}
