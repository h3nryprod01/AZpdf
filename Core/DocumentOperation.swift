import Foundation

/// Cross-platform intent model. Platform adapters decide how each operation is
/// rendered and persisted while preserving this behavior contract.
public enum DocumentOperation: Equatable, Sendable {
    public enum AnnotationKind: String, Equatable, Sendable {
        case note
        case highlight
        case freeText
        case signature
        case image
    }

    case rotate(page: Int)
    case duplicate(page: Int)
    case delete(page: Int)
    case movePages(from: [Int], destination: Int)
    case insertPages(count: Int, at: Int)
    case addAnnotation(kind: AnnotationKind, page: Int)
    case redact(pages: [Int])
}
