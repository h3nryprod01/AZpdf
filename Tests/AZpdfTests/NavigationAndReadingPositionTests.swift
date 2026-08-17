import PDFKit
import XCTest
@testable import AZpdf

// Characterization cho 5 tiện ích UX (issue #2 #4 #6 #7 #8) — ghim hành vi ở tầng store,
// không phụ thuộc GUI. Mỗi test nói rõ hợp đồng nó canh.
@MainActor
final class NavigationAndReadingPositionTests: XCTestCase {

    private let positionsKey = "readingPositions"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: positionsKey)
        UserDefaults.standard.removeObject(forKey: "pdfDisplayModeChoice")
        UserDefaults.standard.removeObject(forKey: "pdfDisplaysAsBook")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: positionsKey)
        UserDefaults.standard.removeObject(forKey: "pdfDisplayModeChoice")
        UserDefaults.standard.removeObject(forKey: "pdfDisplaysAsBook")
        super.tearDown()
    }

    // MARK: #2 — Go to page

    func testGoToPageJumpsWithOneBasedNumberAndRejectsOutOfRange() throws {
        let store = DocumentStore()
        store.open(try writeTemporaryPDF(pageCount: 5))

        XCTAssertTrue(store.goToPage(3))
        XCTAssertEqual(store.selectedPageIndex, 2, "người dùng đánh số từ 1, index từ 0")

        // Ngoài khoảng: TỪ CHỐI, không clamp — gõ 500 vào tài liệu 5 trang phải được báo sai,
        // không phải âm thầm bị đưa tới trang cuối.
        XCTAssertFalse(store.goToPage(0))
        XCTAssertFalse(store.goToPage(6))
        XCTAssertEqual(store.selectedPageIndex, 2, "nhảy hỏng không được đổi vị trí")
    }

    func testGoToPageWithoutDocumentFails() {
        XCTAssertFalse(DocumentStore().goToPage(1))
    }

    // MARK: #8 — Zoom theo phần trăm

    func testSetZoomPercentClampsToSameRangeAsButtons() {
        let store = DocumentStore()
        store.setZoomPercent(125)
        XCTAssertEqual(store.zoomScale, 1.25, accuracy: 0.001)
        XCTAssertFalse(store.isAutoScale, "gõ số nghĩa là rời chế độ Fit Page")

        // Cùng biên [0.5, 4] với zoomIn/zoomOut — không tồn tại mức zoom chỉ vào được bằng gõ số.
        store.setZoomPercent(10)
        XCTAssertEqual(store.zoomScale, 0.5, accuracy: 0.001)
        store.setZoomPercent(9999)
        XCTAssertEqual(store.zoomScale, 4, accuracy: 0.001)
    }

    // MARK: #6 — Xoay ngược chiều

    func testRotateCounterClockwiseIsMinus90AndOneUndoStep() throws {
        let store = DocumentStore()
        store.open(try writeTemporaryPDF(pageCount: 1))
        let before = store.document!.page(at: 0)!.rotation

        store.rotateCurrentPageCounterClockwise()
        let after = store.document!.page(at: 0)!.rotation
        XCTAssertEqual(((after - before) % 360 + 360) % 360, 270, "CCW = +270 ≡ −90")

        // MỘT bước undo phải về nguyên trạng — không phải ba lần undo cho ba lần rotate nội bộ.
        store.undo()
        XCTAssertEqual(store.document!.page(at: 0)!.rotation, before)
    }

    // MARK: #4 — Nhớ vị trí đọc

    func testReopeningRestoresLastReadPage() throws {
        let url = try writeTemporaryPDF(pageCount: 7)
        let first = DocumentStore()
        first.open(url)
        first.selectedPageIndex = 4

        let second = DocumentStore()
        second.open(url)
        XCTAssertEqual(second.selectedPageIndex, 4, "mở lại phải về đúng trang đang đọc dở")
    }

    func testRestoredPositionClampsWhenDocumentShrank() throws {
        let url = try writeTemporaryPDF(pageCount: 3)
        // Giả lập tài liệu từng dài hơn: vị trí lưu 9 > pageCount 3.
        UserDefaults.standard.set([url.path: 9], forKey: positionsKey)

        let store = DocumentStore()
        store.open(url)
        XCTAssertEqual(store.selectedPageIndex, 2, "clamp về trang cuối, không cuộn vào hư không")
    }

    // MARK: #7 — Chế độ hiển thị

    func testDisplayModeChoicePersistsAcrossStores() {
        let store = DocumentStore()
        XCTAssertEqual(store.displayModeChoice, .singleContinuous, "mặc định một cột liên tục")

        store.displayModeChoice = .twoUpContinuous
        store.displaysAsBook = true

        XCTAssertEqual(DocumentStore().displayModeChoice, .twoUpContinuous)
        XCTAssertTrue(DocumentStore().displaysAsBook)
    }

    func testDisplayModeMapsToPDFKit() {
        XCTAssertEqual(PDFDisplayModeChoice.singleContinuous.pdfKitMode, .singlePageContinuous)
        XCTAssertEqual(PDFDisplayModeChoice.twoUpContinuous.pdfKitMode, .twoUpContinuous)
        XCTAssertEqual(PDFDisplayModeChoice.twoUp.pdfKitMode, .twoUp)
    }

    // MARK: helper

    private func writeTemporaryPDF(pageCount: Int) throws -> URL {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let image = NSImage(size: CGSize(width: 100, height: 140))
            image.lockFocus(); NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 100, height: 140).fill(); image.unlockFocus()
            if let page = PDFPage(image: image) { document.insert(page, at: index) }
        }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "azpdf-nav-\(UUID().uuidString).pdf")
        try XCTUnwrap(document.dataRepresentation()).write(to: url)
        return url
    }
}
