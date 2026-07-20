import Foundation
import XCTest
@testable import AZpdfCore

final class DocumentIRTests: XCTestCase {
    func testRoundTripPreservesStructuredContent() throws {
        let document = makeDocument()
        let data = try DocumentIRCodec.encode(document)
        let decoded = try DocumentIRCodec.decodeAndValidate(data)

        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.pages[0].coordinateSpace, .pagePointsTopLeft)
        XCTAssertEqual(decoded.pages[0].blocks[1].table?.cells[1].columnSpan, 2)
        XCTAssertEqual(decoded.pages[0].blocks[2].formula?.latex, "E = mc^2")
    }

    func testFixtureDecodesThroughPublicCodec() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/document-ir-v1.json")
        let document = try DocumentIRCodec.decodeAndValidate(Data(contentsOf: fixture))

        XCTAssertEqual(document.provenance.modelID, "fixture-layout-model")
        XCTAssertEqual(document.pages[0].blocks.count, 4)
        XCTAssertEqual(document.pages[0].blocks[1].table?.cells.count, 4)
    }

    func testPlainTextUsesReadingOrderAndStructuredFallbacks() throws {
        let document = makeDocument()

        XCTAssertEqual(
            document.plainText,
            "Tiêu đề\nE = mc^2\nTên\tGiá trị\nAZpdf\tMiễn phí\nSơ đồ luồng xử lý"
        )
    }

    func testRejectsUnknownReadingOrderBlock() {
        var document = makeDocument()
        document.pages[0].readingOrder.append("missing")

        XCTAssertThrowsError(try document.validate()) { error in
            XCTAssertEqual(
                error as? DocumentIRValidationError,
                .missingReadingOrderBlock(page: 0, blockID: "missing")
            )
        }
    }

    func testRejectsOutOfBoundsGeometryAndConfidence() {
        var geometry = makeDocument()
        geometry.pages[0].blocks[0].bounds = PDFRect(x: 580, y: 20, width: 30, height: 20)
        XCTAssertThrowsError(try geometry.validate()) { error in
            XCTAssertEqual(
                error as? DocumentIRValidationError,
                .invalidGeometry(page: 0, ownerID: "heading")
            )
        }

        var confidence = makeDocument()
        confidence.pages[0].blocks[0].confidence = 1.01
        XCTAssertThrowsError(try confidence.validate()) { error in
            XCTAssertEqual(
                error as? DocumentIRValidationError,
                .invalidConfidence(ownerID: "heading")
            )
        }
    }

    func testRejectsInvalidPayloadAndRelation() {
        var payload = makeDocument()
        payload.pages[0].blocks[2].formula = nil
        XCTAssertThrowsError(try payload.validate()) { error in
            XCTAssertEqual(
                error as? DocumentIRValidationError,
                .incompatiblePayload(blockID: "formula", kind: .formula)
            )
        }

        var relation = makeDocument()
        relation.relations = [
            .init(kind: .captionOf, sourceBlockID: "figure", targetBlockID: "missing")
        ]
        XCTAssertThrowsError(try relation.validate()) { error in
            XCTAssertEqual(error as? DocumentIRValidationError, .missingRelationEndpoint("missing"))
        }
    }

    func testCoordinateConversionRoundTrips() {
        let pdfRect = PDFRect(x: 40, y: 650, width: 180, height: 32)
        let topLeft = DocumentIR.Geometry.topLeftRect(fromPDFRect: pdfRect, pageHeight: 842)

        XCTAssertEqual(topLeft, PDFRect(x: 40, y: 160, width: 180, height: 32))
        XCTAssertEqual(
            DocumentIR.Geometry.pdfRect(fromTopLeftRect: topLeft, pageHeight: 842),
            pdfRect
        )
    }

    func testRejectsMissingFigureCaptionReference() {
        var document = makeDocument()
        document.pages[0].blocks[3].figure?.captionBlockIDs = ["missing-caption"]

        XCTAssertThrowsError(try document.validate()) { error in
            XCTAssertEqual(
                error as? DocumentIRValidationError,
                .invalidFigureCaptionReference(
                    figureBlockID: "figure",
                    captionBlockID: "missing-caption"
                )
            )
        }
    }

    private func makeDocument() -> DocumentIR {
        let heading = DocumentIR.Block(
            id: "heading",
            kind: .heading,
            bounds: PDFRect(x: 40, y: 30, width: 220, height: 28),
            confidence: 0.99,
            language: "vi",
            text: "Tiêu đề",
            style: .init(fontFamily: "Inter", fontSize: 18, fontWeight: 700)
        )
        let table = DocumentIR.Block(
            id: "table",
            kind: .table,
            bounds: PDFRect(x: 40, y: 150, width: 360, height: 120),
            confidence: 0.94,
            table: .init(
                rowCount: 2,
                columnCount: 3,
                cells: [
                    .init(row: 0, column: 0, bounds: PDFRect(x: 40, y: 150, width: 120, height: 50), text: "Tên"),
                    .init(row: 0, column: 1, columnSpan: 2, bounds: PDFRect(x: 160, y: 150, width: 240, height: 50), text: "Giá trị"),
                    .init(row: 1, column: 0, bounds: PDFRect(x: 40, y: 200, width: 120, height: 70), text: "AZpdf"),
                    .init(row: 1, column: 1, columnSpan: 2, bounds: PDFRect(x: 160, y: 200, width: 240, height: 70), text: "Miễn phí")
                ]
            )
        )
        let formula = DocumentIR.Block(
            id: "formula",
            kind: .formula,
            bounds: PDFRect(x: 40, y: 90, width: 180, height: 32),
            confidence: 0.92,
            formula: .init(latex: "E = mc^2", mathML: "<math><mi>E</mi></math>", confidence: 0.9)
        )
        let figure = DocumentIR.Block(
            id: "figure",
            kind: .figure,
            bounds: PDFRect(x: 40, y: 310, width: 300, height: 180),
            confidence: 0.88,
            figure: .init(altText: "Sơ đồ luồng xử lý", classification: "diagram")
        )
        let artifact = DocumentIR.Block(
            id: "footer",
            kind: .footer,
            bounds: PDFRect(x: 40, y: 800, width: 200, height: 20),
            isArtifact: true,
            text: "Không đưa vào text đọc"
        )

        return DocumentIR(
            metadata: .init(title: "Fixture", sourceFilename: "fixture.pdf", primaryLanguage: "vi"),
            provenance: .init(
                providerID: "org.azpdf.fixture",
                providerVersion: "1.0",
                modelID: "fixture-layout",
                generatedAtRFC3339: "2026-07-18T00:00:00Z",
                languages: ["vi", "en"]
            ),
            pages: [
                .init(
                    index: 0,
                    size: PDFSize(width: 595, height: 842),
                    blocks: [heading, table, formula, figure, artifact],
                    readingOrder: ["heading", "formula", "table", "figure", "footer"]
                )
            ],
            relations: [
                .init(kind: .readingOrderBefore, sourceBlockID: "heading", targetBlockID: "formula")
            ]
        )
    }
}
