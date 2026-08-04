import PDFKit
import XCTest

// B3.5.2 — the simulated-scan corpus MUST be image-only: if any page carried a text
// layer, AZpdf would read that layer (PDFPage.string) instead of OCR, and the corpus
// would not exercise the path this phase exists to test. This guard proves otherwise.
final class ScannedFixtureTests: XCTestCase {
    func testScannedFixturesHaveNoTextLayer() throws {
        let dir = URL(fileURLWithPath: #filePath)      // .../Tests/AZpdfTests/<this>
            .deletingLastPathComponent()                // .../Tests/AZpdfTests
            .deletingLastPathComponent()                // .../Tests
            .appendingPathComponent("Fixtures/scanned") // .../Tests/Fixtures/scanned

        let pdfs = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "pdf" }
        XCTAssertGreaterThanOrEqual(pdfs.count, 8, "expected ≥ 8 scanned fixtures in \(dir.path)")

        for url in pdfs {
            let doc = try XCTUnwrap(PDFDocument(url: url), "open \(url.lastPathComponent)")
            for pageIndex in 0..<doc.pageCount {
                let text = (doc.page(at: pageIndex)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertTrue(text.isEmpty,
                              "\(url.lastPathComponent) page \(pageIndex) has a text layer — corpus must be image-only to force OCR")
            }
        }
    }
}
