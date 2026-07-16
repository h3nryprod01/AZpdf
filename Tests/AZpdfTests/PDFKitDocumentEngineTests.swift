import AppKit
import PDFKit
import XCTest
@testable import AZpdf
import AZpdfCore

final class PDFKitDocumentEngineTests: XCTestCase {
    func testAdapterAppliesPortablePageOperations() throws {
        let engine = PDFKitDocumentEngine()
        let document = makeDocument(pageCount: 2)

        try engine.apply(.rotate(page: 0), to: document)
        try engine.apply(.duplicate(page: 0), to: document)
        try engine.apply(.delete(page: 1), to: document)

        XCTAssertEqual(engine.pageCount(of: document), 2)
        XCTAssertEqual(document.page(at: 0)?.rotation, 90)
    }

    func testAdapterRejectsUnsupportedPortableOperation() {
        let engine = PDFKitDocumentEngine()
        let document = makeDocument(pageCount: 1)

        XCTAssertThrowsError(try engine.apply(.redact(pages: [0]), to: document)) { error in
            XCTAssertEqual(error as? PDFEngineError, .operationNotSupported)
        }
    }

    private func makeDocument(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()
        for _ in 0..<pageCount {
            let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 100,
                pixelsHigh: 140,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: .alphaFirst,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!
            let image = NSImage(size: representation.size)
            image.addRepresentation(representation)
            document.insert(PDFPage(image: image)!, at: document.pageCount)
        }
        return document
    }
}
