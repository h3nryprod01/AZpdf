import Foundation

public enum PDFEngineError: Error, Equatable, Sendable {
    case invalidDocument
    case invalidPageIndex
    case operationNotSupported
    case passwordRequired
    case invalidPassword
    case readOnlyDocument
    case ioFailure(String)
}

/// Platform boundary for PDF engines. The core never imports PDFKit, AppKit or UI frameworks.
public protocol PDFDocumentEngine {
    associatedtype Document: AnyObject

    var capabilities: PDFEngineCapabilities { get }

    func load(data: Data) throws -> Document
    func dataRepresentation(of document: Document) throws -> Data
    func pageCount(of document: Document) -> Int
    func apply(_ operation: DocumentOperation, to document: Document) throws
}

/// Optional reading contract shared by PDFKit, MuPDF and future engines.
/// An adapter only advertises these features after implementing this protocol.
public protocol PDFDocumentReadingEngine: PDFDocumentEngine {
    func metadata(of document: Document) throws -> PDFDocumentMetadata
    func pageDescriptor(at index: Int, in document: Document) throws -> PDFPageDescriptor
    func text(ofPage index: Int, in document: Document) throws -> String
    func annotations(onPage index: Int, in document: Document) throws -> [PDFAnnotationDescriptor]
    func render(_ request: PDFRenderRequest, in document: Document) throws -> PDFRenderedPage
}

public extension PDFDocumentReadingEngine {
    func search(_ query: String, in document: Document) throws -> [PDFSearchMatch] {
        guard !query.isEmpty else { return [] }
        return try (0..<pageCount(of: document)).compactMap { pageIndex in
            let pageText = try text(ofPage: pageIndex, in: document)
            guard pageText.localizedCaseInsensitiveContains(query) else { return nil }
            return PDFSearchMatch(pageIndex: pageIndex, text: query)
        }
    }
}

public protocol PDFDocumentOutlineEngine: PDFDocumentEngine {
    func outline(of document: Document) throws -> [PDFOutlineItem]
}

public protocol PDFDocumentFormEngine: PDFDocumentEngine {
    func formFields(in document: Document) throws -> [PDFFormFieldDescriptor]
}

public protocol PDFDocumentSecurityEngine: PDFDocumentEngine {
    func security(of document: Document) -> PDFDocumentSecurity
    func unlock(_ document: Document, password: String) throws
}

public protocol PDFDocumentEmbeddedFileEngine: PDFDocumentEngine {
    func embeddedFiles(in document: Document) throws -> [PDFEmbeddedFileDescriptor]
    func data(forEmbeddedFile id: String, in document: Document) throws -> Data
}

public protocol PDFDocumentStructuredTextEngine: PDFDocumentEngine {
    func structuredText(ofPage index: Int, in document: Document) throws -> PDFPageTextLayout
}

public protocol PDFOCRProcessor {
    func capabilities() throws -> PDFOCRCapabilities
    func process(
        _ request: PDFOCRRequest,
        input: URL,
        output: URL
    ) throws -> PDFOCRResult
}

public protocol PDFDigitalSignatureProcessor {
    func capabilities() throws -> PDFSignatureCapabilities
    func verify(input: URL) throws -> PDFSignatureVerification
    func sign(
        _ request: PDFSignatureRequest,
        input: URL,
        output: URL,
        pkcs12: URL,
        passwordFile: URL
    ) throws -> PDFSignatureResult
}
