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
        // Không giao kết quả là chưa đủ: lượt đã huỷ cũng không được KHỞI ĐỘNG tìm kiếm.
        // Thiếu assert này thì bỏ `guard !Task.isCancelled` vẫn qua được test, vì
        // cancel() đã bỏ callback rồi — lãng phí một lượt quét toàn tài liệu mà không ai thấy.
        XCTAssertFalse(document.isFinding, "lượt đã huỷ không được khởi động find")
    }

    /// Huỷ khi lượt tìm ĐANG BAY — khác hẳn huỷ trước khi debounce trôi qua.
    ///
    /// Đây là đường mà bản đầu tiên bị lỗi: `cancelFindString()` chạy trước khi gỡ observer,
    /// nên `handleEnd` vẫn kích và giao kết quả dở dang; tệ hơn, nó set `onResults = nil`
    /// khiến kết quả đúng của lượt kế tiếp không bao giờ tới. Trong thực tế đây chính là
    /// tình huống gõ thêm một ký tự vào ô tìm kiếm trên tài liệu lớn.
    func testCancelDuringFlightStopsDelivery() async throws {
        let document = makeTextDocument(pageCount: 4000, containing: "needle")
        let runner = PDFSearchRunner(debounce: .zero, sleeper: { _ in })
        let expectation = expectation(description: "không giao sau khi huỷ lượt đang bay")
        expectation.isInverted = true
        runner.search("needle", in: document) { _ in expectation.fulfill() }
        // Nhường luồng để Task chạy tới startFind, tức find thật sự bắt đầu.
        try? await Task.sleep(for: .milliseconds(1))
        try XCTSkipUnless(document.isFinding,
                          "máy này tìm xong 4000 trang quá nhanh nên không đo được đường đang-bay")
        runner.cancel()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    /// Huỷ xong thì runner phải NHẢ callback.
    ///
    /// Trong lúc một lượt còn đang chờ, closure giữ chặt captures của nó là đúng — đó là
    /// cách closure hoạt động, không phải rò. Điều runner phải bảo đảm là sau `cancel()`
    /// nó không ôm callback nữa. Nếu ôm, và callback lại giữ chủ sở hữu runner (ở
    /// `PDFReaderView` là Coordinator), thì thành vòng giữ và Coordinator không bao giờ
    /// chết — kéo theo cả `PDFView` lẫn tài liệu. Bản đầu tiên không null `onResults` trong
    /// `cancel()`, nên đóng tab giữa lúc đang tìm là rò nguyên tài liệu.
    func testCancelReleasesTheCallbackSoItsOwnerCanDie() {
        @MainActor final class Owner { let runner = PDFSearchRunner(sleeper: { _ in }) }
        weak var weakOwner: Owner?
        do {
            let owner = Owner()
            weakOwner = owner
            owner.runner.search("x", in: makeTextDocument(pageCount: 2, containing: "x")) { _ in
                _ = owner   // cố ý bắt mạnh, đúng như call site từng làm
            }
            XCTAssertNotNil(weakOwner, "lượt còn đang chờ thì giữ là đúng")
            owner.runner.cancel()
        }
        XCTAssertNil(weakOwner, "sau cancel() runner phải nhả callback; còn sống = vòng giữ")
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
