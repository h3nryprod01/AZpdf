import PDFKit
import XCTest
@testable import AZpdf

@MainActor
final class AnnotationFormattingTests: XCTestCase {

    private func makeStore() -> DocumentStore {
        let store = DocumentStore()
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        store.document = document
        return store
    }

    private func makeFreeText(in store: DocumentStore) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: CGRect(x: 20, y: 20, width: 200, height: 60), forType: .freeText, withProperties: nil)
        annotation.contents = "Xin chào"
        annotation.font = .systemFont(ofSize: 14)
        store.document?.page(at: 0)?.addAnnotation(annotation)
        store.selectAnnotation(annotation, pageIndex: 0)
        return annotation
    }

    func testFreeTextAppliesFamilyTraitsAndAlignment() throws {
        let store = makeStore()
        let annotation = makeFreeText(in: store)

        store.selectedAnnotationFontName = "Times New Roman"
        store.selectedAnnotationFontSize = 22
        store.selectedAnnotationIsBold = true
        store.selectedAnnotationIsItalic = true
        store.selectedAnnotationAlignment = .center
        store.updateSelectedFreeText()

        let font = try XCTUnwrap(annotation.font)
        XCTAssertEqual(font.familyName, "Times New Roman")
        XCTAssertEqual(font.pointSize, 22)
        let traits = NSFontManager.shared.traits(of: font)
        XCTAssertTrue(traits.contains(.boldFontMask), "Bold toggle must reach the PDF font")
        XCTAssertTrue(traits.contains(.italicFontMask), "Italic toggle must reach the PDF font")
        XCTAssertEqual(annotation.alignment, .center)
    }

    func testFreeTextBoxFrameAndFillAreOptional() throws {
        let store = makeStore()
        let annotation = makeFreeText(in: store)

        store.selectedAnnotationHasBorder = true
        store.selectedAnnotationBorderColor = .systemBlue
        store.selectedAnnotationLineWidth = 3
        store.selectedAnnotationHasFill = true
        store.selectedAnnotationFillColor = .systemYellow
        store.updateSelectedFreeText()

        XCTAssertEqual(annotation.border?.lineWidth, 3)
        XCTAssertNotNil(annotation.interiorColor)

        // Unticking must actually clear them, not just leave the last colour in
        // place with the toggle showing off.
        store.selectedAnnotationHasBorder = false
        store.selectedAnnotationHasFill = false
        store.updateSelectedFreeText()

        XCTAssertEqual(annotation.border?.lineWidth, 0)
        XCTAssertNil(annotation.interiorColor)
    }

    // A freshly placed text box uses the system font, whose family is the
    // hidden ".AppleSystemUIFont". Left as-is it is not in the picker's list,
    // so the picker renders with nothing selected.
    func testSystemFontFallsBackToASelectableFamily() {
        let store = makeStore()
        let annotation = makeFreeText(in: store)
        annotation.font = .systemFont(ofSize: 14)

        store.selectAnnotation(annotation, pageIndex: 0)

        XCTAssertTrue(store.availableFontFamilies.contains(store.selectedAnnotationFontName),
                      "The picker must always have a selectable family, got \(store.selectedAnnotationFontName)")
    }

    func testSelectingAnnotationLoadsItsCurrentFormatting() throws {
        let store = makeStore()
        let annotation = makeFreeText(in: store)
        annotation.font = try XCTUnwrap(NSFontManager.shared.font(withFamily: "Georgia", traits: .italicFontMask, weight: 5, size: 19))
        annotation.alignment = .right
        annotation.interiorColor = .systemGreen
        let border = PDFBorder()
        border.lineWidth = 4
        annotation.border = border

        store.selectAnnotation(annotation, pageIndex: 0)

        XCTAssertEqual(store.selectedAnnotationFontName, "Georgia")
        XCTAssertEqual(store.selectedAnnotationFontSize, 19)
        XCTAssertTrue(store.selectedAnnotationIsItalic)
        XCTAssertFalse(store.selectedAnnotationIsBold)
        XCTAssertEqual(store.selectedAnnotationAlignment, .right)
        XCTAssertTrue(store.selectedAnnotationHasFill)
        XCTAssertTrue(store.selectedAnnotationHasBorder)
        XCTAssertEqual(store.selectedAnnotationLineWidth, 4)
    }

    // PDFKit writes a default `/DA (/Helvetica 12 Tf 0 g)` onto every
    // annotation, so reading `fontColor` first would show black in the picker
    // for a red rectangle — and then quietly repaint it black on Apply.
    func testSelectingShapeLoadsStrokeColourNotTheDefaultFontColour() throws {
        let store = makeStore()
        let annotation = ShapeAnnotationFactory.make(
            .rectangle, bounds: CGRect(x: 10, y: 10, width: 80, height: 40),
            stroke: .systemRed, fill: nil, lineWidth: 5
        )
        store.document?.page(at: 0)?.addAnnotation(annotation)

        store.selectAnnotation(annotation, pageIndex: 0)

        let loaded = try XCTUnwrap(store.selectedAnnotationColor.usingColorSpace(.deviceRGB))
        let expected = try XCTUnwrap(NSColor.systemRed.usingColorSpace(.deviceRGB))
        XCTAssertEqual(loaded.redComponent, expected.redComponent, accuracy: 0.05)
        XCTAssertEqual(loaded.blueComponent, expected.blueComponent, accuracy: 0.05)
        XCTAssertEqual(store.selectedAnnotationLineWidth, 5)
    }

    func testUpdateSelectedShapeRestylesAndRemembersDefaults() throws {
        let store = makeStore()
        let annotation = ShapeAnnotationFactory.make(
            .oval, bounds: CGRect(x: 10, y: 10, width: 80, height: 40),
            stroke: .black, fill: nil, lineWidth: 1
        )
        store.document?.page(at: 0)?.addAnnotation(annotation)
        store.selectAnnotation(annotation, pageIndex: 0)

        store.selectedAnnotationColor = .systemBlue
        store.selectedAnnotationLineWidth = 7
        store.selectedAnnotationHasFill = true
        store.selectedAnnotationFillColor = .systemGreen
        store.updateSelectedShape()

        XCTAssertEqual(annotation.border?.lineWidth, 7)
        XCTAssertNotNil(annotation.interiorColor)
        XCTAssertTrue(store.canUndo, "Restyling must be undoable")
        XCTAssertEqual(store.shapeLineWidth, 7, "The next shape inserted should inherit this width")
    }

    func testUpdateSelectedShapeIgnoresNonShapes() {
        let store = makeStore()
        let annotation = makeFreeText(in: store)
        let originalWidth = annotation.border?.lineWidth

        store.selectedAnnotationLineWidth = 9
        store.updateSelectedShape()

        XCTAssertEqual(annotation.border?.lineWidth, originalWidth, "A text box must not be restyled by the shape editor")
    }
}
