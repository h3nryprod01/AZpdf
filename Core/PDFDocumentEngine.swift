import Foundation

public enum PDFEngineError: Error, Equatable, Sendable {
    case invalidDocument
    case invalidPageIndex
    case operationNotSupported
}

/// Platform boundary for PDF engines. The core never imports PDFKit, AppKit or UI frameworks.
public protocol PDFDocumentEngine {
    associatedtype Document

    func load(data: Data) throws -> Document
    func dataRepresentation(of document: Document) throws -> Data
    func pageCount(of document: Document) -> Int
    func apply(_ operation: DocumentOperation, to document: Document) throws
}
