import AppKit
import PDFKit
import XCTest
@testable import AZpdf

/// Print goes through `PDFDocument.printOperation(for:scalingMode:autoRotate:)`
/// (see .forge/2026-07-23-in-an-print/plan.md), not PDFView — PDFView only
/// exposes a fire-and-forget `print(with:autoRotate:)` that runs straight to
/// the panel with nothing to configure or assert on. `makePrintOperation()`
/// builds without running, so these tests can inspect its configuration and
/// even drive the operation fully headless.
@MainActor
final class DocumentPrintingTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)          // .../Tests/AZpdfTests/<this file>
            .deletingLastPathComponent()          // .../Tests/AZpdfTests
            .deletingLastPathComponent()          // .../Tests
            .appendingPathComponent("Fixtures/source/two-page.pdf")
    }

    func testMakePrintOperationReturnsNilWithoutDocument() {
        let store = DocumentStore()
        XCTAssertNil(store.makePrintOperation())
    }

    func testMakePrintOperationConfiguresJobTitleAndPanelFlags() throws {
        let store = DocumentStore()
        store.document = try XCTUnwrap(PDFDocument(url: fixtureURL))
        store.fileURL = fixtureURL

        let operation = try XCTUnwrap(store.makePrintOperation())

        XCTAssertEqual(operation.jobTitle, store.title)
        XCTAssertTrue(operation.showsPrintPanel)
        XCTAssertTrue(operation.printInfo !== NSPrintInfo.shared, "must build a fresh NSPrintInfo, not mutate the shared one")

        // scalingMode/autoRotate aren't public on NSPrintOperation, but PDFKit
        // records them in printInfo under these keys (verified by probe on this
        // machine: 0/1/2 = none/toFit/downToFit, autoRotate as 0/1). Without
        // this pin, mutating either builder argument passes every test — their
        // visual effect (rotated pages, oversized pages) is exactly the risk
        // the plan flags. If a future PDFKit renames the keys, update or drop
        // these two asserts; the GUI check (plan step 5) still covers behavior.
        let attributes = operation.printInfo.dictionary()
        XCTAssertEqual(
            attributes[NSPrintInfo.AttributeKey(rawValue: "PDFPrintScalingMode")] as? Int,
            PDFPrintScalingMode.pageScaleDownToFit.rawValue
        )
        XCTAssertEqual(attributes[NSPrintInfo.AttributeKey(rawValue: "PDFPrintAutoRotate")] as? Bool, true)
    }

    /// End-to-end headless path probed manually before writing this test (see
    /// plan.md, "Bối cảnh khảo sát" #3): jobDisposition = .save + jobSavingURL
    /// + both panels off lets NSPrintOperation.run() print straight to a PDF
    /// file with no UI at all — no window, no app bundle needed.
    func testPrintOperationRunsHeadlessAndProducesAllPages() throws {
        let store = DocumentStore()
        store.document = try XCTUnwrap(PDFDocument(url: fixtureURL))
        store.fileURL = fixtureURL
        let operation = try XCTUnwrap(store.makePrintOperation())
        let outputURL = FileManager.default.temporaryDirectory.appending(path: "azpdf-print-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        operation.printInfo.jobDisposition = .save
        operation.printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = outputURL
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        XCTAssertTrue(operation.run())
        XCTAssertEqual(PDFDocument(url: outputURL)?.pageCount, 2)
    }

    /// Pins the assumption (probed manually, not just assumed) that AZpdf's own
    /// annotations print by default. If a future OS/PDFKit version flips
    /// `shouldPrint`'s default, this goes red before a user discovers
    /// highlights/ink silently missing from a printout.
    func testAppCreatedAnnotationsPrintByDefault() {
        let highlight = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 10, height: 10), forType: .highlight, withProperties: nil)
        let ink = PDFAnnotation(bounds: CGRect(x: 0, y: 0, width: 10, height: 10), forType: .ink, withProperties: nil)

        XCTAssertTrue(highlight.shouldPrint)
        XCTAssertTrue(ink.shouldPrint)
    }
}
