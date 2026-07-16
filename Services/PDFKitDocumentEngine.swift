import PDFKit
import AZpdfCore

/// macOS adapter. A Windows/Linux engine must conform to the same core contract.
struct PDFKitDocumentEngine: PDFDocumentEngine {
    func load(data: Data) throws -> PDFDocument {
        guard let document = PDFDocument(data: data) else { throw PDFEngineError.invalidDocument }
        return document
    }

    func dataRepresentation(of document: PDFDocument) throws -> Data {
        guard let data = document.dataRepresentation() else { throw PDFEngineError.invalidDocument }
        return data
    }

    func pageCount(of document: PDFDocument) -> Int { document.pageCount }

    func apply(_ operation: DocumentOperation, to document: PDFDocument) throws {
        switch operation {
        case let .rotate(page):
            guard let pdfPage = document.page(at: page) else { throw PDFEngineError.invalidPageIndex }
            pdfPage.rotation = (pdfPage.rotation + 90) % 360
        case let .duplicate(page):
            guard let pdfPage = document.page(at: page), let copy = pdfPage.copy() as? PDFPage else {
                throw PDFEngineError.invalidPageIndex
            }
            document.insert(copy, at: page + 1)
        case let .delete(page):
            guard document.pageCount > 1, document.page(at: page) != nil else {
                throw PDFEngineError.invalidPageIndex
            }
            document.removePage(at: page)
        case let .movePages(from, destination):
            guard !from.isEmpty, from.allSatisfy({ document.page(at: $0) != nil }) else {
                throw PDFEngineError.invalidPageIndex
            }
            let pages = from.compactMap { document.page(at: $0) }
            for index in from.sorted(by: >) { document.removePage(at: index) }
            let adjustedDestination = max(0, min(destination, document.pageCount))
            for (offset, page) in pages.enumerated() { document.insert(page, at: adjustedDestination + offset) }
        case .insertPages, .addAnnotation, .redact:
            throw PDFEngineError.operationNotSupported
        }
    }
}
