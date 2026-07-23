import PDFKit
import XCTest
@testable import AZpdf

final class ShapeAnnotationTests: XCTestCase {

    // MARK: - Pure geometry

    func testStarPointsAlternateOuterAndInnerRadius() {
        let size = CGSize(width: 100, height: 100)
        let points = ShapeAnnotationFactory.starPoints(in: size)

        XCTAssertEqual(points.count, 10, "A five-pointed star needs five outer and five inner vertices")

        let center = CGPoint(x: 50, y: 50)
        func radius(_ point: CGPoint) -> CGFloat { hypot(point.x - center.x, point.y - center.y) }
        // Fitting the star to its bounds scales x and y by slightly different
        // factors, so the radii are no longer exact constants — but every point
        // of the star must still stick out well beyond every notch, or it stops
        // reading as a star at all.
        let outer = points.enumerated().filter { $0.offset.isMultiple(of: 2) }.map { radius($0.element) }
        let inner = points.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map { radius($0.element) }
        XCTAssertGreaterThan(try XCTUnwrap(outer.min()), try XCTUnwrap(inner.max()) * 1.8)

        // Without this the star renders rotated — a valid decagon, but not a
        // star anyone recognises.
        XCTAssertEqual(points[0].x, 50, accuracy: 0.01, "First vertex points straight up")
        XCTAssertEqual(points[0].y, 100, accuracy: 0.01)
    }

    // A star's vertices only touch its circumscribed circle at five angles, so
    // laying them out on that circle leaves the shape floating inside the
    // selection frame instead of following it.
    func testStarPointsFillTheirBoundsExactly() {
        for size in [CGSize(width: 200, height: 50), CGSize(width: 60, height: 300), CGSize(width: 100, height: 100)] {
            let points = ShapeAnnotationFactory.starPoints(in: size)
            XCTAssertEqual(points.map(\.x).min() ?? -1, 0, accuracy: 0.01, "size \(size)")
            XCTAssertEqual(points.map(\.y).min() ?? -1, 0, accuracy: 0.01, "size \(size)")
            XCTAssertEqual(points.map(\.x).max() ?? 0, size.width, accuracy: 0.01, "size \(size)")
            XCTAssertEqual(points.map(\.y).max() ?? 0, size.height, accuracy: 0.01, "size \(size)")
        }
    }

    func testTrianglePointsSpanBounds() {
        let points = ShapeAnnotationFactory.trianglePoints(in: CGSize(width: 80, height: 60))
        XCTAssertEqual(points, [CGPoint(x: 40, y: 60), CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 0)])
    }

    // MARK: - Geometry that does not follow bounds

    // A Line stores its endpoints in `/L`, apart from `/Rect`. Resizing only
    // `bounds` therefore leaves the selection frame in the new place and the
    // drawn line in the old one.
    func testResizingLineRewritesEndpoints() {
        let annotation = ShapeAnnotationFactory.make(
            .line, bounds: CGRect(x: 0, y: 0, width: 100, height: 50),
            stroke: .black, fill: nil, lineWidth: 2
        )
        annotation.bounds = CGRect(x: 300, y: 300, width: 40, height: 200)
        annotation.refreshAZpdfShapeGeometry()

        XCTAssertEqual(annotation.startPoint, CGPoint(x: 0, y: 0))
        XCTAssertEqual(annotation.endPoint, CGPoint(x: 40, y: 200), "Endpoint must track the new size, not the size at creation")
    }

    func testResizingStarRebuildsInkPathsToNewSize() throws {
        let annotation = ShapeAnnotationFactory.make(
            .star, bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            stroke: .black, fill: nil, lineWidth: 2
        )
        let originalMaxX = try XCTUnwrap(annotation.paths?.first).bounds.maxX
        XCTAssertEqual(originalMaxX, 100, accuracy: 1)

        annotation.bounds = CGRect(x: 0, y: 0, width: 300, height: 100)
        annotation.refreshAZpdfShapeGeometry()

        XCTAssertEqual(annotation.paths?.count, 1, "Rebuilding must replace the old path, not stack a second one on top")
        XCTAssertEqual(try XCTUnwrap(annotation.paths?.first).bounds.maxX, 300, accuracy: 1)
    }

    func testRefreshIsNoOpForNonShapeAnnotations() {
        let signature = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 50, height: 50), forType: .ink, withProperties: nil)
        let path = NSBezierPath()
        path.move(to: .zero)
        path.line(to: CGPoint(x: 10, y: 10))
        signature.add(path)

        signature.refreshAZpdfShapeGeometry()

        XCTAssertEqual(signature.paths?.count, 1, "A hand-drawn signature must never have its strokes replaced by a shape outline")
    }

    // MARK: - Type flags

    func testShapeKindSurvivesSaveAndReopen() throws {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        let annotation = ShapeAnnotationFactory.make(
            .star, bounds: CGRect(x: 100, y: 100, width: 80, height: 80),
            stroke: .red, fill: nil, lineWidth: 2
        )
        document.page(at: 0)?.addAnnotation(annotation)

        let data = try XCTUnwrap(document.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let restored = try XCTUnwrap(reloaded.page(at: 0)?.annotations.first)

        // Reopened as a plain Ink annotation, the star would be treated as a
        // signature and resize would silently mangle it.
        XCTAssertEqual(restored.azpdfShapeKind, .star)
        XCTAssertTrue(restored.isAZpdfShape)
        XCTAssertFalse(restored.isAZpdfInk, "An ink-drawn shape must not be mistaken for a hand-drawn signature")
    }

    func testShapesAreMovableResizableAndFreeform() {
        for kind in ShapeKind.allCases {
            let annotation = ShapeAnnotationFactory.make(
                kind, bounds: CGRect(x: 0, y: 0, width: 60, height: 60),
                stroke: .black, fill: .white, lineWidth: 2
            )
            XCTAssertTrue(annotation.isAZpdfMovable, "\(kind) should be draggable")
            XCTAssertTrue(annotation.isAZpdfResizable, "\(kind) should have resize handles")
            XCTAssertTrue(annotation.isAZpdfFreeformResize, "\(kind) should resize each axis independently")
        }
    }

    func testOnlyClosedShapesCarryAFill() {
        XCTAssertNil(
            ShapeAnnotationFactory.make(.line, bounds: CGRect(x: 0, y: 0, width: 60, height: 60),
                                        stroke: .black, fill: .white, lineWidth: 2).interiorColor,
            "A line has no interior to fill"
        )
        XCTAssertNotNil(
            ShapeAnnotationFactory.make(.rectangle, bounds: CGRect(x: 0, y: 0, width: 60, height: 60),
                                        stroke: .black, fill: .white, lineWidth: 2).interiorColor
        )
    }

    // The Inspector's annotation list is driven by `documentRevision`, because
    // @Observable cannot see an annotation added straight to a PDFKit page.
    // Without the bump it showed a stale count after every placement.
    @MainActor
    func testFinishingPlacementBumpsDocumentRevision() {
        let store = DocumentStore()
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        store.document = document
        let before = store.documentRevision

        store.finishAnnotationPlacement(.addAnnotation(kind: .shape, page: 0))

        XCTAssertGreaterThan(store.documentRevision, before)
        XCTAssertNil(store.placementInstruction)
        XCTAssertTrue(store.isModified)
    }

    // MARK: - Render verification

    // Saving regenerates `/AP`, so a shape can round-trip perfectly and still
    // be invisible in the open document — which is what the user sees. This
    // rasterises the live page with no save in between.
    func testShapesRenderLiveWithoutSaving() throws {
        for kind in ShapeKind.allCases {
            let document = PDFDocument()
            document.insert(PDFPage(), at: 0)
            let page = try XCTUnwrap(document.page(at: 0))
            let bounds = CGRect(x: 100, y: 300, width: 160, height: 120)
            page.addAnnotation(ShapeAnnotationFactory.make(
                kind, bounds: bounds,
                stroke: .systemRed, fill: nil, lineWidth: 2
            ))

            XCTAssertTrue(RedPixelScan(page: page).containsRed(in: bounds.insetBy(dx: -8, dy: -8)),
                          "\(kind) must be visible in the open document, not only after saving")
        }
    }

    // The bug-F net, applied to shapes: a shape that is written into the file
    // but renders nowhere is the worst failure mode, because every UI step
    // reports success. Round-tripping through a data representation forces
    // PDFKit to regenerate the appearance stream; a raster of the reloaded page
    // must then actually show the shape.
    //
    // Old and new bounds are deliberately disjoint so a no-op resize cannot
    // pass: the shape would still be at the old bounds, failing the first
    // assertion. The second assertion catches a resize that duplicated the
    // shape rather than moving it.
    func testResizedShapesStillRenderAfterRoundTrip() throws {
        for kind in ShapeKind.allCases {
            let document = PDFDocument()
            document.insert(PDFPage(), at: 0)
            let original = CGRect(x: 20, y: 20, width: 60, height: 60)
            let annotation = ShapeAnnotationFactory.make(
                kind, bounds: original,
                stroke: NSColor(red: 1, green: 0, blue: 0, alpha: 1), fill: nil, lineWidth: 6
            )
            document.page(at: 0)?.addAnnotation(annotation)

            let resized = CGRect(x: 220, y: 300, width: 140, height: 100)
            annotation.bounds = resized
            annotation.refreshAZpdfShapeGeometry()

            let data = try XCTUnwrap(document.dataRepresentation())
            let page = try XCTUnwrap(PDFDocument(data: data)?.page(at: 0))
            let scan = RedPixelScan(page: page)

            XCTAssertTrue(scan.containsRed(in: resized.insetBy(dx: -8, dy: -8)),
                          "\(kind) must render inside its resized bounds after a round trip")
            XCTAssertFalse(scan.containsRed(in: original),
                           "\(kind) must not still render at the pre-resize bounds")
        }
    }
}

/// Rasterises a page once and answers "is any red ink inside this rect?".
/// Rect is in PDF page coordinates (origin bottom-left); the bitmap's origin is
/// top-left, hence the y flip.
private struct RedPixelScan {
    let bitmap: NSBitmapImageRep
    let pageBounds: CGRect

    init(page: PDFPage) {
        pageBounds = page.bounds(for: .mediaBox)
        let thumbnail = page.thumbnail(of: pageBounds.size, for: .mediaBox)
        let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        bitmap = NSBitmapImageRep(cgImage: cgImage)
    }

    func containsRed(in rect: CGRect) -> Bool {
        let scaleX = CGFloat(bitmap.pixelsWide) / pageBounds.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / pageBounds.height
        let minX = max(0, Int(rect.minX * scaleX))
        let maxX = min(bitmap.pixelsWide, Int(rect.maxX * scaleX))
        let minY = max(0, Int((pageBounds.height - rect.maxY) * scaleY))
        let maxY = min(bitmap.pixelsHigh, Int((pageBounds.height - rect.minY) * scaleY))
        for x in stride(from: minX, to: maxX, by: 1) {
            for y in stride(from: minY, to: maxY, by: 1) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent > 0.6, color.greenComponent < 0.4, color.blueComponent < 0.4 { return true }
            }
        }
        return false
    }
}

@MainActor
final class ArrowNudgeTests: XCTestCase {
    private func event(keyCode: UInt16, shift: Bool = false) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero,
            modifierFlags: shift ? .shift : [],
            timestamp: 0, windowNumber: 0, context: nil,
            characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: keyCode
        ))
    }

    // The arrow keys are the only non-drag way to move an annotation, so a
    // regression here silently removes the keyboard/VoiceOver path entirely.
    func testEachArrowMapsToItsOwnDirection() throws {
        XCTAssertEqual(PlacementPDFView.arrowNudge(for: try event(keyCode: 123)), CGSize(width: -2, height: 0))
        XCTAssertEqual(PlacementPDFView.arrowNudge(for: try event(keyCode: 124)), CGSize(width: 2, height: 0))
        // Page space has y increasing upwards, so Down must be negative.
        XCTAssertEqual(PlacementPDFView.arrowNudge(for: try event(keyCode: 125)), CGSize(width: 0, height: -2))
        XCTAssertEqual(PlacementPDFView.arrowNudge(for: try event(keyCode: 126)), CGSize(width: 0, height: 2))
    }

    func testShiftGivesACoarserStep() throws {
        XCTAssertEqual(PlacementPDFView.arrowNudge(for: try event(keyCode: 126, shift: true)), CGSize(width: 0, height: 16))
    }

    func testNonArrowKeysAreNotConsumed() throws {
        // 51 is Delete — swallowing it here would break deleting a selection.
        XCTAssertNil(PlacementPDFView.arrowNudge(for: try event(keyCode: 51)))
        XCTAssertNil(PlacementPDFView.arrowNudge(for: try event(keyCode: 53)))
    }
}
