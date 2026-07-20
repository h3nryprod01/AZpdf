import Foundation

/// Cross-platform intent model. Platform adapters decide how each operation is
/// rendered and persisted while preserving this behavior contract.
public enum DocumentOperation: Equatable, Sendable {
    public typealias AnnotationKind = PDFAnnotationKind

    case rotate(page: Int)
    case duplicate(page: Int)
    case delete(page: Int)
    case movePages(from: [Int], destination: Int)
    case insertPages(count: Int, at: Int)
    case addAnnotation(kind: AnnotationKind, page: Int)
    case redact(pages: [Int])
    case insertDocument(data: Data, pages: [Int]?, at: Int)
    case setMetadata(PDFDocumentMetadata)
    case upsertAnnotation(PDFAnnotationDescriptor)
    case upsertImageAnnotation(PDFAnnotationDescriptor, imageData: Data?, format: PDFImageFormat)
    case removeAnnotation(id: String, page: Int)
    case flattenAnnotations(pages: [Int])
    case setFormValue(fieldID: String, value: String?)
    case setOutline([PDFOutlineItem])
    case upsertEmbeddedFile(PDFEmbeddedFileDescriptor, data: Data)
    case removeEmbeddedFile(id: String)
}
