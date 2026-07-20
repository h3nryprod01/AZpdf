import AppKit
import PDFKit
import XCTest
@testable import AZpdf

/// Covers README features whose logic can be exercised without driving the GUI.
/// The panel-backed entry points (NSOpenPanel/NSSavePanel) block on runModal and
/// are therefore verified by hand; everything they call into is verified here.
@MainActor
final class ReadmeFeatureTests: XCTestCase {

    // MARK: - "Xuất bản sao PDF được bảo vệ bằng mật khẩu"

    func testProtectedCopyIsActuallyLockedAndOpensOnlyWithTheRightPassword() throws {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 2)
        let destination = temporaryURL(suffix: "protected.pdf")

        XCTAssertTrue(store.writeProtectedCopy(to: destination, password: "secret"))

        let reopened = try XCTUnwrap(PDFDocument(url: destination))
        XCTAssertTrue(reopened.isLocked, "bản sao phải bị khoá")
        XCTAssertFalse(reopened.unlock(withPassword: "sai-mat-khau"))
        XCTAssertTrue(reopened.unlock(withPassword: "secret"))
        XCTAssertEqual(reopened.pageCount, 2)
    }

    func testProtectedCopyRefusesEmptyPassword() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)

        XCTAssertFalse(store.writeProtectedCopy(to: temporaryURL(suffix: "empty.pdf"), password: ""))
    }

    // MARK: - "Lưu đè hoặc xuất ra PDF mới"

    func testExportWritesAReadableCopyWithoutTouchingTheOriginal() throws {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 3)
        let destination = temporaryURL(suffix: "copy.pdf")

        store.export(to: destination)

        XCTAssertNil(store.lastError)
        let reopened = try XCTUnwrap(PDFDocument(url: destination))
        XCTAssertEqual(reopened.pageCount, 3)
        XCTAssertEqual(store.pageCount, 3, "xuất bản sao không được đổi tài liệu đang mở")
        XCTAssertFalse(store.isModified, "xuất bản sao không phải là chỉnh sửa")
    }

    func testExportReportsAnErrorForAnUnwritableDestination() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)

        store.export(to: URL(fileURLWithPath: "/thu-muc-khong-ton-tai/copy.pdf"))

        XCTAssertNotNil(store.lastError, "đường dẫn hỏng phải báo lỗi, không im lặng")
    }

    // MARK: - "Danh sách tối đa 8 tài liệu gần đây" + "Kéo và thả PDF vào cửa sổ"

    /// Both the recents list and the drag-and-drop handler funnel into
    /// `store.open(_:)`, so this covers the shared path they rely on.
    func testOpeningAFileLoadsItAndRecordsItInRecents() throws {
        let store = DocumentStore()
        let source = temporaryURL(suffix: "recent.pdf")
        try XCTUnwrap(makeDocument(pageCount: 2).dataRepresentation()).write(to: source)

        store.openRecentDocument(source)

        XCTAssertEqual(store.pageCount, 2)
        XCTAssertEqual(store.fileURL, source)
        XCTAssertFalse(store.isModified)
        XCTAssertTrue(store.recentDocumentPaths.contains(source.path))
    }

    func testRecentsKeepsAtMostEightEntriesMostRecentFirst() throws {
        let store = DocumentStore()
        var urls: [URL] = []
        for index in 0..<10 {
            let url = temporaryURL(suffix: "recent-\(index).pdf")
            try XCTUnwrap(makeDocument(pageCount: 1).dataRepresentation()).write(to: url)
            store.open(url)
            urls.append(url)
        }

        XCTAssertEqual(store.recentDocumentPaths.count, 8, "README hứa tối đa 8 mục")
        XCTAssertEqual(store.recentDocumentPaths.first, urls.last?.path, "mới nhất phải đứng đầu")
    }

    func testRemovingARecentDocumentDropsItFromTheList() throws {
        let store = DocumentStore()
        let url = temporaryURL(suffix: "removable.pdf")
        try XCTUnwrap(makeDocument(pageCount: 1).dataRepresentation()).write(to: url)
        store.open(url)
        XCTAssertTrue(store.recentDocumentPaths.contains(url.path))

        store.removeRecentDocument(url)

        XCTAssertFalse(store.recentDocumentPaths.contains(url.path))
    }

    func testOpeningANonPDFReportsAnError() {
        let store = DocumentStore()
        let bogus = temporaryURL(suffix: "not-a.pdf")
        try? Data("day khong phai PDF".utf8).write(to: bogus)

        store.open(bogus)

        XCTAssertNil(store.document)
        XCTAssertNotNil(store.lastError)
    }

    // MARK: - "OCR vùng kéo trực tiếp"

    func testRegionOCRArmsTheReaderAndShowsAnInstructionWithoutRecordingUndo() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let revisionBefore = store.documentRevision

        store.beginOCRRegionSelection()

        XCTAssertNotNil(store.placementInstruction, "phải hướng dẫn người dùng kéo chọn vùng")
        XCTAssertFalse(store.canUndo, "mới chỉ chọn vùng thì chưa có gì để hoàn tác")
        XCTAssertFalse(store.isModified, "chọn vùng OCR không phải chỉnh sửa tài liệu")
        XCTAssertEqual(store.documentRevision, revisionBefore)
    }

    func testRegionOCRDoesNothingWithoutADocument() {
        let store = DocumentStore()

        store.beginOCRRegionSelection()

        XCTAssertNil(store.placementInstruction)
    }

    // MARK: - "Ký CMS/PKCS#7 bằng certificate trong Keychain"

    /// Producing a real .p7s needs a signing identity in the Keychain, which a
    /// test cannot create. What is testable is the first step of that flow —
    /// querying the Keychain must succeed rather than throw, whether or not the
    /// machine happens to have an identity installed.
    func testCertificateIdentityLookupQueriesTheKeychainWithoutFailing() {
        XCTAssertNoThrow(try CertificateSigningService.availableIdentities())
    }

    func testCertificateSigningDoesNothingWithoutADocument() {
        let store = DocumentStore()

        store.beginCertificateSigning()

        XCTAssertFalse(store.isCertificateSigningSheetPresented)
        XCTAssertTrue(store.certificateSigningIdentities.isEmpty)
    }

    // MARK: - "OCR pipeline hybrid: ưu tiên text layer, Vision cho trang scan"

    /// The hybrid pipeline picks its source per page: an embedded text layer
    /// when there is one, Vision otherwise. A page built from an image has no
    /// text layer, so it must fall through to the Vision branch.
    func testImageOnlyPageHasNoTextLayerSoOCRFallsBackToVision() throws {
        let document = makeDocument(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))

        let textLayer = OCRService.textLayer(from: page)

        XCTAssertTrue(textLayer == nil || textLayer?.isEmpty == true,
                      "trang ảnh không có text layer thì phải rơi sang nhánh Vision")
    }

    // MARK: - Helpers

    private func temporaryURL(suffix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "azpdf-readme-\(UUID().uuidString)-\(suffix)")
    }

    private func makeDocument(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let image = NSImage(size: CGSize(width: 120, height: 160))
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 120, height: 160).fill()
            image.unlockFocus()
            if let page = PDFPage(image: image) { document.insert(page, at: index) }
        }
        return document
    }
}
