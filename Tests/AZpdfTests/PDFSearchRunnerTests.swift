import AppKit
import PDFKit
import XCTest
@testable import AZpdf

/// Ghim chặt hợp đồng hành vi của `PDFSearchRunner`: tìm kiếm phải bất đồng bộ
/// (qua `beginFindString`), gõ nhanh chỉ chạy một lượt, chuỗi rỗng xoá ngay,
/// và huỷ được — chứ không quay lại `findString` đồng bộ trên main thread.
@MainActor
final class PDFSearchRunnerTests: XCTestCase {

    // MARK: - Hợp đồng hành vi (B3)

    func testSearchDeliversResultsAsynchronously() async throws {
        let document = makeTextDocument(pageCount: 20, containing: "needle")
        let runner = PDFSearchRunner(debounce: .milliseconds(10), sleeper: { _ in })
        var delivered = false
        var captured: [PDFSelection] = []
        let expectation = expectation(description: "kết quả được giao")
        runner.search("needle", in: document) { results in
            delivered = true
            captured = results
            expectation.fulfill()
        }
        XCTAssertFalse(delivered, "callback phải chưa chạy tại lúc search() trả về (bất đồng bộ)")
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssertEqual(captured.count, 20, "tài liệu 20 trang mỗi trang 1 match → 20 kết quả")
    }

    func testRapidTypingRunsOneSearch() async throws {
        let document = makeTextDocument(pageCount: 5, containing: "abc")
        let runner = PDFSearchRunner(debounce: .milliseconds(10), sleeper: { _ in })
        var callCount = 0
        var lastResults: [PDFSelection] = []
        let expectation = expectation(description: "chỉ kết quả của 'abc' được giao")
        runner.search("a", in: document) { _ in callCount += 1 }
        runner.search("ab", in: document) { _ in callCount += 1 }
        runner.search("abc", in: document) { results in
            callCount += 1
            lastResults = results
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssertEqual(callCount, 1, "gõ 3 ký tự liên tiếp phải chỉ chạy đúng 1 lượt tìm (của 'abc')")
        XCTAssertEqual(lastResults.count, 5)
    }

    func testEmptyQueryClearsImmediatelyWithoutSearching() {
        let document = makeTextDocument(pageCount: 3, containing: "x")
        let runner = PDFSearchRunner(debounce: .milliseconds(10), sleeper: { _ in })
        var receivedEmpty = false
        runner.search("", in: document) { results in receivedEmpty = results.isEmpty }
        XCTAssertTrue(receivedEmpty, "chuỗi rỗng phải gọi onResults([]) ngay")
        XCTAssertFalse(document.isFinding, "chuỗi rỗng không được khởi động lượt tìm nào")
    }

    func testCancelStopsDelivery() async throws {
        let document = makeTextDocument(pageCount: 50, containing: "word")
        let runner = PDFSearchRunner(debounce: .milliseconds(10), sleeper: { _ in })
        let expectation = expectation(description: "callback không bao giờ chạy")
        expectation.isInverted = true
        runner.search("word", in: document) { _ in expectation.fulfill() }
        runner.cancel()
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testResultsMatchSynchronousFindString() async throws {
        let document = makeTextDocument(pageCount: 12, containing: "marker")
        let syncCount = document.findString("marker", withOptions: .caseInsensitive).count
        let runner = PDFSearchRunner(debounce: .milliseconds(10), sleeper: { _ in })
        let expectation = expectation(description: "kết quả bất đồng bộ")
        var asyncCount = -1
        runner.search("marker", in: document) { results in
            asyncCount = results.count
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssertEqual(asyncCount, syncCount, "số kết quả bất đồng bộ phải khớp findString đồng bộ")
    }

    // MARK: - Helper

    /// Dựng tài liệu có **chữ thật** trên mỗi trang, khác với `makeDocument(pageCount:)`
    /// trong các file test khác (trang ảnh trắng → `findString` trả 0, vô nghĩa cho test
    /// tìm kiếm). Vẽ `text` bằng `NSAttributedString.draw(in:)` trong PDF graphics context
    /// để chữ lọt vào content stream, PDFKit mới tìm được.
    private func makeTextDocument(pageCount: Int, containing text: String) -> PDFDocument {
        let pageData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        guard let consumer = CGDataConsumer(data: pageData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return PDFDocument()
        }
        let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 24)])
        let drawRect = CGRect(x: 72, y: 360, width: 468, height: 200)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        for _ in 0..<pageCount {
            ctx.beginPDFPage(nil)
            attributed.draw(in: drawRect)
            ctx.endPDFPage()
        }
        NSGraphicsContext.restoreGraphicsState()
        ctx.closePDF()
        return PDFDocument(data: pageData as Data) ?? PDFDocument()
    }

    func testHelperProducesSearchableText() {
        let document = makeTextDocument(pageCount: 3, containing: "cụm từ mốc")
        let matches = document.findString("cụm từ mốc", withOptions: .caseInsensitive)
        XCTAssertEqual(matches.count, 3,
                       "Helper phải vẽ chữ thật lên mỗi trang; 0 = helper hỏng, sửa helper đừng sửa assert.")
    }
}
