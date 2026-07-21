import XCTest
import PDFKit
@testable import AZpdf

/// Ghim chặt ánh xạ toạ độ chữ ký tay sang annotation-local space.
///
/// Bug cũ (d85f1b1) map nhầm sang page-space (`bounds.minX + …, bounds.maxY - …`)
/// đẩy toàn bộ nét mực ra ngoài `/Rect`; mọi renderer clip mất → chữ ký "im lặng".
/// Output đúng phải là annotation-local: không phụ thuộc annotation nằm đâu trên trang.
final class SignaturePointTests: XCTestCase {
    func testMapsToLocalSpaceNotPageSpace() {
        let atOrigin = CGRect(x: 0, y: 0, width: 260, height: 96)
        let shifted  = CGRect(x: 300, y: 400, width: 260, height: 96)
        let canvasPt = CGPoint(x: 0, y: SignatureCanvasMetrics.size.height) // đáy-trái canvas
        let a = PDFReaderView.signaturePoint(canvasPt, in: atOrigin)
        let b = PDFReaderView.signaturePoint(canvasPt, in: shifted)
        XCTAssertEqual(a.x, b.x, accuracy: 0.01, "x phải là local-space")
        XCTAssertEqual(a.y, b.y, accuracy: 0.01, "y phải là local-space")
        XCTAssertEqual(a.x, 0, accuracy: 0.01)
        XCTAssertEqual(a.y, 0, accuracy: 0.01)
    }

    func testCanvasCornerMapsToBoundsCorner() {
        let bounds = CGRect(x: 10, y: 20, width: 260, height: 96)
        let topRight = PDFReaderView.signaturePoint(
            CGPoint(x: SignatureCanvasMetrics.size.width, y: 0), in: bounds)
        XCTAssertEqual(topRight.x, 260, accuracy: 0.01)
        XCTAssertEqual(topRight.y, 96, accuracy: 0.01)
    }
}
