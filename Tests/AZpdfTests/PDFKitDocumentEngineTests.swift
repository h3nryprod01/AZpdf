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

    func testAdapterReadsMetadataPageAndRendersPNG() throws {
        let engine = PDFKitDocumentEngine()
        let document = makeDocument(pageCount: 1)
        try engine.apply(
            .setMetadata(PDFDocumentMetadata(title: "AZpdf", keywords: ["PDF/UA", "PDF/A"])),
            to: document
        )

        let metadata = try engine.metadata(of: document)
        let page = try engine.pageDescriptor(at: 0, in: document)
        let rendered = try engine.render(PDFRenderRequest(pageIndex: 0, scale: 0.5), in: document)

        XCTAssertEqual(metadata.title, "AZpdf")
        XCTAssertEqual(metadata.keywords, ["PDF/UA", "PDF/A"])
        XCTAssertFalse(page.cropBox.isEmpty)
        XCTAssertEqual(rendered.format, .png)
        XCTAssertFalse(rendered.data.isEmpty)
        XCTAssertTrue(engine.capabilities.contains([.open, .save, .render]))
    }

    func testAdapterReadsAndUpdatesFormField() throws {
        let engine = PDFKitDocumentEngine()
        let document = makeDocument(pageCount: 1)
        let field = PDFAnnotation(
            bounds: CGRect(x: 10, y: 10, width: 120, height: 24),
            forType: .widget,
            withProperties: nil
        )
        field.widgetFieldType = .text
        field.fieldName = "full_name"
        field.widgetStringValue = "Before"
        document.page(at: 0)?.addAnnotation(field)

        XCTAssertEqual(try engine.formFields(in: document).first?.value, "Before")
        try engine.apply(.setFormValue(fieldID: "full_name", value: "After"), to: document)
        XCTAssertEqual(try engine.formFields(in: document).first?.value, "After")
    }

    func testAdapterReadsOutlineAndSecurity() throws {
        let engine = PDFKitDocumentEngine()
        let document = makeDocument(pageCount: 1)
        let root = PDFOutline()
        let child = PDFOutline()
        child.label = "Trang đầu"
        child.destination = PDFDestination(page: document.page(at: 0)!, at: .zero)
        root.insertChild(child, at: 0)
        document.outlineRoot = root

        let outline = try engine.outline(of: document)
        let security = engine.security(of: document)

        XCTAssertEqual(outline.first?.title, "Trang đầu")
        XCTAssertEqual(outline.first?.pageIndex, 0)
        XCTAssertFalse(security.isEncrypted)
        XCTAssertFalse(security.isLocked)
    }

    func testAdapterPassesSharedEngineConformance() throws {
        let engine = PDFKitDocumentEngine()
        let document = makeDocument(pageCount: 2)

        let report = PDFEngineConformance.validate(engine, document: document)

        XCTAssertTrue(report.isConformant, "\(report.issues)")
        XCTAssertEqual(report.pageCount, 2)
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
