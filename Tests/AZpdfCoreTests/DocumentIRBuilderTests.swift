import XCTest
@testable import AZpdfCore

final class DocumentIRBuilderTests: XCTestCase {
    func testBuildsBaselineFromTopLeftEngineLayout() throws {
        let layout = PDFPageTextLayout(
            pageIndex: 0,
            coordinateSpace: .pageTopLeft,
            blocks: [
                PDFTextBlock(
                    kind: .text,
                    bounds: PDFRect(x: 40, y: 50, width: 250, height: 30),
                    lines: [
                        PDFTextLine(
                            bounds: PDFRect(x: 40, y: 50, width: 250, height: 30),
                            text: "AZpdf MuPDF baseline",
                            fontName: "Inter-Regular",
                            fontFamily: "Inter",
                            fontSize: 12
                        )
                    ]
                ),
                PDFTextBlock(kind: .image, bounds: PDFRect(x: 40, y: 100, width: 300, height: 180))
            ]
        )

        let document = try DocumentIRBuilder.buildBaseline(
            layouts: [layout],
            pageDescriptors: [descriptor()],
            provenance: .init(providerID: "org.azpdf.mupdf", providerVersion: "1.28.0")
        )

        XCTAssertEqual(document.pages[0].readingOrder, ["p0-b0", "p0-b1"])
        XCTAssertEqual(document.pages[0].blocks[0].kind, .paragraph)
        XCTAssertEqual(document.pages[0].blocks[0].style?.fontFamily, "Inter")
        XCTAssertEqual(document.pages[0].blocks[1].kind, .figure)
        XCTAssertEqual(document.plainText, "AZpdf MuPDF baseline")
    }

    func testMapsBottomLeftGeometryAcrossPageRotations() throws {
        let source = PDFRect(x: 40, y: 650, width: 180, height: 32)
        let expected: [Int: PDFRect] = [
            0: PDFRect(x: 40, y: 160, width: 180, height: 32),
            90: PDFRect(x: 650, y: 40, width: 32, height: 180),
            180: PDFRect(x: 375, y: 650, width: 180, height: 32),
            270: PDFRect(x: 160, y: 375, width: 32, height: 180)
        ]

        for rotation in [0, 90, 180, 270] {
            let layout = PDFPageTextLayout(
                pageIndex: 0,
                coordinateSpace: .pdfBottomLeft,
                blocks: [PDFTextBlock(kind: .text, bounds: source)]
            )
            let document = try DocumentIRBuilder.buildBaseline(
                layouts: [layout],
                pageDescriptors: [descriptor(rotation: rotation)],
                provenance: .init(providerID: "fixture")
            )

            XCTAssertEqual(document.pages[0].blocks[0].bounds, expected[rotation])
            XCTAssertEqual(
                document.pages[0].size,
                rotation == 90 || rotation == 270
                    ? PDFSize(width: 842, height: 595)
                    : PDFSize(width: 595, height: 842)
            )
        }
    }

    func testRejectsMissingDescriptorAndDuplicateLayoutPage() {
        let layout = PDFPageTextLayout(pageIndex: 0, coordinateSpace: .pageTopLeft, blocks: [])

        XCTAssertThrowsError(try DocumentIRBuilder.buildBaseline(
            layouts: [layout],
            pageDescriptors: [],
            provenance: .init(providerID: "fixture")
        )) { error in
            XCTAssertEqual(error as? DocumentIRBuilderError, .missingPageDescriptor(0))
        }

        XCTAssertThrowsError(try DocumentIRBuilder.buildBaseline(
            layouts: [layout, layout],
            pageDescriptors: [descriptor()],
            provenance: .init(providerID: "fixture")
        )) { error in
            XCTAssertEqual(error as? DocumentIRBuilderError, .duplicateLayoutPage(0))
        }

        XCTAssertThrowsError(try DocumentIRBuilder.buildBaseline(
            layouts: [layout],
            pageDescriptors: [descriptor(), descriptor()],
            provenance: .init(providerID: "fixture")
        )) { error in
            XCTAssertEqual(error as? DocumentIRBuilderError, .duplicatePageDescriptor(0))
        }
    }

    private func descriptor(rotation: Int = 0) -> PDFPageDescriptor {
        PDFPageDescriptor(
            index: 0,
            mediaBox: PDFRect(x: 0, y: 0, width: 595, height: 842),
            cropBox: PDFRect(x: 0, y: 0, width: 595, height: 842),
            rotation: rotation
        )
    }
}
