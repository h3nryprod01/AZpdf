import XCTest
@testable import AZpdf

@MainActor
final class DocumentWorkspaceTests: XCTestCase {
    func testNewTabBecomesSelected() {
        let workspace = DocumentWorkspace()
        let initialID = workspace.selectedTabID

        workspace.createEmptyTab()

        XCTAssertEqual(workspace.tabs.count, 2)
        XCTAssertNotEqual(workspace.selectedTabID, initialID)
    }

    func testClosingOnlyTabCreatesNewEmptyTab() {
        let workspace = DocumentWorkspace()
        let originalID = workspace.selectedTabID

        workspace.closeTab(originalID)

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertNotEqual(workspace.selectedTabID, originalID)
        XCTAssertNil(workspace.activeStore.document)
    }

    func testModifiedTabIsNotDiscarded() {
        let workspace = DocumentWorkspace()
        workspace.activeStore.isModified = true

        workspace.closeTab(workspace.selectedTabID)

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(workspace.activeStore.lastError, "Hãy lưu thay đổi trước khi đóng tab.")
    }
}
