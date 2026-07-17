import Foundation

struct OCRPageReview: Identifiable, Sendable {
    enum Source: String, Sendable {
        case textLayer
        case vision
        case unavailable

        var displayName: String {
            switch self {
            case .textLayer: "Text layer PDF"
            case .vision: "OCR Vision"
            case .unavailable: "Không nhận dạng"
            }
        }
    }

    let pageIndex: Int
    let source: Source
    let confidence: Float?
    let lineCount: Int
    let warning: String?

    var id: Int { pageIndex }
    var confidencePercent: Int? { confidence.map { Int(($0 * 100).rounded()) } }
    var needsReview: Bool { warning != nil || (confidence ?? 1) < 0.85 }
}
