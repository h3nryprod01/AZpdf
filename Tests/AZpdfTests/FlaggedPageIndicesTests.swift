import XCTest
@testable import AZpdf

// B3.5.6 — flaggedPageIndices is the pure predicate the searchable-PDF export uses to
// decide whether to warn before baking text permanently. Kept isolated from NSSavePanel
// (which can't run headless) so the guard logic itself is testable.
final class FlaggedPageIndicesTests: XCTestCase {
    func testFlaggedPageIndicesReturnsOnlyWarnedPages() {
        let reviews = [
            OCRPageReview(pageIndex: 0, source: .vision, confidence: 0.9, lineCount: 5, layoutSummary: "s", warning: nil),
            OCRPageReview(pageIndex: 1, source: .vision, confidence: 0.9, lineCount: 5, layoutSummary: "s", warning: "x"),
            OCRPageReview(pageIndex: 2, source: .textLayer, confidence: nil, lineCount: 5, layoutSummary: "s", warning: nil),
            OCRPageReview(pageIndex: 3, source: .vision, confidence: 0.9, lineCount: 5, layoutSummary: "s", warning: "y"),
            OCRPageReview(pageIndex: 4, source: .vision, confidence: 0.9, lineCount: 5, layoutSummary: "s", warning: nil),
        ]
        XCTAssertEqual(DocumentStore.flaggedPageIndices(reviews), [1, 3])
    }

    func testFlaggedPageIndicesEmptyWhenNoneWarned() {
        let reviews = [
            OCRPageReview(pageIndex: 0, source: .vision, confidence: 0.9, lineCount: 5, layoutSummary: "s", warning: nil),
            OCRPageReview(pageIndex: 1, source: .textLayer, confidence: nil, lineCount: 5, layoutSummary: "s", warning: nil),
        ]
        XCTAssertEqual(DocumentStore.flaggedPageIndices(reviews), [])
    }

    func testFlaggedPageIndicesEmptyForEmptyInput() {
        XCTAssertEqual(DocumentStore.flaggedPageIndices([]), [])
    }
}
