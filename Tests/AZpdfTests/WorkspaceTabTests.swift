import PDFKit
import XCTest
@testable import AZpdf

@MainActor
final class WorkspaceTabTests: XCTestCase {

    func testOpeningAFileTakesOverTheEmptyStartingTab() throws {
        let workspace = DocumentWorkspace()
        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertNil(workspace.activeStore.document)

        workspace.openInNewTab(try writeTemporaryPDF(pageCount: 2))

        XCTAssertEqual(workspace.tabs.count, 1, "tab rỗng phải được tái dùng, không đẻ tab mới")
        XCTAssertEqual(workspace.activeStore.pageCount, 2)
    }

    func testOpeningASecondFileAddsATabInsteadOfReplacingTheOpenOne() throws {
        let workspace = DocumentWorkspace()
        workspace.openInNewTab(try writeTemporaryPDF(pageCount: 2))
        workspace.openInNewTab(try writeTemporaryPDF(pageCount: 3))

        XCTAssertEqual(workspace.tabs.count, 2, "tab đang có tài liệu thì không được ghi đè")
        XCTAssertEqual(workspace.activeStore.pageCount, 3)
        XCTAssertEqual(workspace.tabs[0].store.pageCount, 2)
    }

    private func writeTemporaryPDF(pageCount: Int) throws -> URL {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let image = NSImage(size: CGSize(width: 100, height: 140))
            image.lockFocus(); NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 100, height: 140).fill(); image.unlockFocus()
            if let page = PDFPage(image: image) { document.insert(page, at: index) }
        }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "azpdf-tab-\(UUID().uuidString).pdf")
        try XCTUnwrap(document.dataRepresentation()).write(to: url)
        return url
    }
}
