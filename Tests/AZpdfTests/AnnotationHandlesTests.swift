import XCTest
@testable import AZpdf

final class AnnotationHandlesTests: XCTestCase {
    private let rect = CGRect(x: 100, y: 100, width: 60, height: 40)

    func testHandleRectsAreCenteredOnCornersAndEdgeMidpoints() {
        let handles = AnnotationHandles(rect: rect, handleSize: 8)
        let rects = handles.handleRects(includeEdges: true)

        XCTAssertEqual(rects[.topLeft]?.midX, rect.minX)
        XCTAssertEqual(rects[.topLeft]?.midY, rect.maxY)
        XCTAssertEqual(rects[.bottomRight]?.midX, rect.maxX)
        XCTAssertEqual(rects[.bottomRight]?.midY, rect.minY)
        XCTAssertEqual(rects[.top]?.midX, rect.midX)
        XCTAssertEqual(rects[.top]?.midY, rect.maxY)
        XCTAssertEqual(rects[.left]?.midX, rect.minX)
        XCTAssertEqual(rects[.left]?.midY, rect.midY)
    }

    func testHandleRectsExcludeEdgesWhenNotRequested() {
        let handles = AnnotationHandles(rect: rect, handleSize: 8)
        let rects = handles.handleRects(includeEdges: false)

        XCTAssertEqual(rects.count, 4)
        XCTAssertNil(rects[.top])
    }

    func testHitPrioritizesHandleOverBodyOverNone() {
        let handles = AnnotationHandles(rect: rect, handleSize: 8)

        XCTAssertEqual(handles.hit(CGPoint(x: rect.minX, y: rect.maxY), includeEdges: true), .handle(.topLeft))
        XCTAssertEqual(handles.hit(CGPoint(x: rect.midX, y: rect.midY), includeEdges: true), .body)
        XCTAssertEqual(handles.hit(CGPoint(x: rect.maxX + 40, y: rect.maxY + 40), includeEdges: true), .none)
    }

    func testHitIgnoresEdgeHandlesWhenNotIncluded() {
        let handles = AnnotationHandles(rect: rect, handleSize: 8)

        // The top-edge midpoint falls inside the body once edges are excluded
        // (image/ink only get 4 corner handles). CGRect.contains excludes the
        // max edge itself, so probe just inside it.
        XCTAssertEqual(handles.hit(CGPoint(x: rect.midX, y: rect.maxY - 1), includeEdges: false), .body)
    }

    func testResizedBoundsCornerFreeVariesBothAxesIndependently() {
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .bottomLeft,
            to: CGPoint(x: rect.minX - 10, y: rect.minY - 30),
            aspectLocked: false,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        // bottomLeft anchors the opposite corner (topRight).
        XCTAssertEqual(resized.maxX, rect.maxX, accuracy: 0.01)
        XCTAssertEqual(resized.maxY, rect.maxY, accuracy: 0.01)
        XCTAssertEqual(resized.width, rect.width + 10, accuracy: 0.01)
        XCTAssertEqual(resized.height, rect.height + 30, accuracy: 0.01)
    }

    func testResizedBoundsCornerLockedPreservesRatioWithEvenScale() {
        // original is 60x40 (ratio 1.5); dragging topRight wants width to grow
        // more (dx=120 -> 2.0x) than height (dy=50 -> 1.25x), so a locked
        // resize must pick the LARGER of the two required scales (2.0, driven
        // by width) and apply it evenly to both axes, landing on an exact
        // 120x80 — not just "some" ratio-preserving size. A ratio-only check
        // can't tell max(...) and min(...) apart (both preserve the ratio),
        // so this pins the exact numbers too: a min(...) mutation would give
        // 75x50 here instead, and that must fail this test.
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .topRight,
            to: CGPoint(x: rect.maxX + 60, y: rect.maxY + 10),
            aspectLocked: true,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertEqual(resized.width / resized.height, rect.width / rect.height, accuracy: 0.01)
        // topRight anchors the opposite corner (bottomLeft).
        XCTAssertEqual(resized.minX, rect.minX, accuracy: 0.01)
        XCTAssertEqual(resized.minY, rect.minY, accuracy: 0.01)
        XCTAssertGreaterThan(resized.width, rect.width)
        XCTAssertEqual(resized.width, 120, accuracy: 0.01)
        XCTAssertEqual(resized.height, 80, accuracy: 0.01)
    }

    func testResizedBoundsHorizontalEdgeChangesOnlyWidth() {
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .right,
            to: CGPoint(x: rect.maxX + 20, y: rect.midY + 200), // y ignored for an edge drag
            aspectLocked: false,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertEqual(resized.height, rect.height, accuracy: 0.01)
        XCTAssertEqual(resized.minX, rect.minX, accuracy: 0.01)
        XCTAssertEqual(resized.width, rect.width + 20, accuracy: 0.01)
    }

    func testResizedBoundsVerticalEdgeChangesOnlyHeight() {
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .top,
            to: CGPoint(x: rect.midX - 200, y: rect.maxY + 15), // x ignored for an edge drag
            aspectLocked: false,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertEqual(resized.width, rect.width, accuracy: 0.01)
        XCTAssertEqual(resized.minY, rect.minY, accuracy: 0.01)
        XCTAssertEqual(resized.height, rect.height + 15, accuracy: 0.01)
    }

    func testResizedBoundsLeftEdgeChangesOnlyWidthAnchoredOnRightEdge() {
        // `.left` and `.right` share `resizedEdge`'s horizontal-edge helper but
        // must anchor the OPPOSITE fixed edge (left anchors maxX, right
        // anchors minX). Pin the anchor explicitly so a min/max mixup between
        // the two handles (a plausible copy-paste bug) fails this test.
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .left,
            to: CGPoint(x: rect.minX - 20, y: rect.midY + 200), // y ignored for an edge drag
            aspectLocked: false,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertEqual(resized.height, rect.height, accuracy: 0.01)
        XCTAssertEqual(resized.maxX, rect.maxX, accuracy: 0.01, "left drag must anchor the right edge in place")
        XCTAssertEqual(resized.width, rect.width + 20, accuracy: 0.01)
    }

    func testResizedBoundsBottomEdgeChangesOnlyHeightAnchoredOnTopEdge() {
        // `.top` and `.bottom` share `resizedEdge`'s vertical-edge helper but
        // must anchor the opposite fixed edge (top anchors minY, bottom
        // anchors maxY). Same min/max-mixup guard as the left-edge test above.
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .bottom,
            to: CGPoint(x: rect.midX - 200, y: rect.minY - 15), // x ignored for an edge drag
            aspectLocked: false,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertEqual(resized.width, rect.width, accuracy: 0.01)
        XCTAssertEqual(resized.maxY, rect.maxY, accuracy: 0.01, "bottom drag must anchor the top edge in place")
        XCTAssertEqual(resized.height, rect.height + 15, accuracy: 0.01)
    }

    func testResizedBoundsEnforcesMinimumSize() {
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .topRight,
            to: CGPoint(x: rect.minX + 2, y: rect.minY + 2), // collapse almost to a point
            aspectLocked: false,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertGreaterThanOrEqual(resized.width, 24)
        XCTAssertGreaterThanOrEqual(resized.height, 24)
    }

    func testResizedBoundsClampsToPageCropBox() {
        let pageBounds = CGRect(x: 0, y: 0, width: 150, height: 150)
        let resized = AnnotationHandles.resizedBounds(
            original: rect,
            handle: .topRight,
            to: CGPoint(x: 400, y: 400), // far past the crop box
            aspectLocked: false,
            minSize: CGSize(width: 24, height: 24),
            within: pageBounds
        )

        XCTAssertLessThanOrEqual(resized.maxX, pageBounds.maxX)
        XCTAssertLessThanOrEqual(resized.maxY, pageBounds.maxY)
    }

    func testResizedBoundsGuardsDivideByZeroWhenOriginalWidthIsZero() {
        let degenerate = CGRect(x: 100, y: 100, width: 0, height: 40)
        let resized = AnnotationHandles.resizedBounds(
            original: degenerate,
            handle: .topRight,
            to: CGPoint(x: 140, y: 160),
            aspectLocked: true,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertFalse(resized.width.isNaN)
        XCTAssertFalse(resized.height.isNaN)
        XCTAssertTrue(resized.width.isFinite)
        XCTAssertTrue(resized.height.isFinite)
    }

    func testResizedBoundsGuardsDivideByZeroWhenOriginalHeightIsZero() {
        let degenerate = CGRect(x: 100, y: 100, width: 60, height: 0)
        let resized = AnnotationHandles.resizedBounds(
            original: degenerate,
            handle: .topRight,
            to: CGPoint(x: 200, y: 140),
            aspectLocked: true,
            minSize: CGSize(width: 24, height: 24),
            within: CGRect(x: 0, y: 0, width: 1_000, height: 1_000)
        )

        XCTAssertFalse(resized.width.isNaN)
        XCTAssertFalse(resized.height.isNaN)
        XCTAssertTrue(resized.width.isFinite)
        XCTAssertTrue(resized.height.isFinite)
    }
}
