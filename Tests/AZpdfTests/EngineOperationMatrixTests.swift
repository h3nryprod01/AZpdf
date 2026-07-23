import XCTest
@testable import AZpdf
import AZpdfCore

/// Pins the PDFKit half of the two-engine operation-conformance matrix (see
/// `Core/PDFEngineOperationConformance.swift` and the MuPDF half in
/// `Tests/AZpdfMuPDFTests/MuPDFOperationMatrixTests.swift`). Both run the same
/// harness against the same fixture so the numbers are comparable.
final class EngineOperationMatrixTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)          // .../Tests/AZpdfTests/<this file>
            .deletingLastPathComponent()          // .../Tests/AZpdfTests
            .deletingLastPathComponent()          // .../Tests
            .appendingPathComponent("Fixtures/source/two-page.pdf")
    }

    /// insertDocument only needs *a* second document to merge in — reusing the
    /// same 2-page fixture keeps this test self-contained.
    private var imagePNG: Data {
        // Minimal valid 1x1 PNG (69 bytes), generated once offline; see
        // code-summary.md for how it was produced.
        Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4z8AAAAMBAQD3A0FDAAAAAElFTkSuQmCC"
        )!
    }

    func testPDFKitLoadsTwoPageFixture() throws {
        let engine = PDFKitDocumentEngine()
        let data = try Data(contentsOf: fixtureURL)
        let document = try engine.load(data: data)

        XCTAssertEqual(engine.pageCount(of: document), 2)
        XCTAssertTrue(try engine.text(ofPage: 0, in: document).contains("AZPDF-P1"))
        XCTAssertTrue(try engine.text(ofPage: 1, in: document).contains("AZPDF-P2"))
    }

    func testPDFKitOperationMatrixBaseline() throws {
        let engine = PDFKitDocumentEngine()
        let data = try Data(contentsOf: fixtureURL)

        let report = PDFEngineOperationConformance.run(engine, data: data, auxiliaryPDF: data, imagePNG: imagePNG)

        // DocumentOperation currently declares 17 cases (Core/DocumentOperation.swift),
        // not the plan's "18". Note this count only pins the harness's own case list;
        // what forces a NEW enum case into the matrix is the exhaustive-switch canary
        // in PDFEngineOperationConformance (compile error until covered), not this line.
        XCTAssertEqual(report.results.count, 17)

        let expectedSupported: Set<String> = [
            "rotate", "duplicate", "delete", "movePages", "insertDocument", "setMetadata"
        ]
        XCTAssertEqual(report.supportedOperations, expectedSupported, "\(report.results)")

        // setFormValue is structurally implemented by PDFKitDocumentEngine, but
        // this fixture has no form field to match, so apply throws
        // operationNotSupported the same way a truly-unimplemented op would.
        let setFormValue = try XCTUnwrap(report.result(for: "setFormValue"))
        XCTAssertEqual(
            setFormValue.status,
            .unsupported,
            "setFormValue phải unsupported trên fixture này (không có form field khớp fieldID), " +
            "không phải vì thiếu code path — chi tiết harness trả về: \(setFormValue.detail)"
        )

        XCTAssertTrue(report.failedOperations.isEmpty, "Không case nào được phép .failed: \(report.failedOperations)")
    }
}
