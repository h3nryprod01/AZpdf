import XCTest
import AZpdfCore
@testable import AZpdfMuPDF

/// MuPDF half of the operation-conformance matrix. See
/// `Tests/AZpdfTests/EngineOperationMatrixTests.swift` for the PDFKit half and
/// `Core/PDFEngineOperationConformance.swift` for the shared harness both run.
final class MuPDFOperationMatrixTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)          // .../Tests/AZpdfMuPDFTests/<this file>
            .deletingLastPathComponent()          // .../Tests/AZpdfMuPDFTests
            .deletingLastPathComponent()          // .../Tests
            .appendingPathComponent("Fixtures/source/two-page.pdf")
    }

    private var imagePNG: Data {
        // Minimal valid 1x1 PNG (69 bytes), generated once offline; see
        // code-summary.md for how it was produced.
        Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4z8AAAAMBAQD3A0FDAAAAAElFTkSuQmCC"
        )!
    }

    /// Skips rather than fails when mutool is missing or too old: the
    /// annotation JS this adapter runs (azpdf_annotations.js) uses ES module
    /// syntax that predates mutool 1.24 (script/qa_linux_smoke.sh gates the
    /// same way). A missing/old tool is not a defect in this code.
    private func makeEngine() throws -> MuPDFDocumentEngine {
        let candidates = [ProcessInfo.processInfo.environment["MUTOOL_BIN"],
                          "/opt/homebrew/bin/mutool",
                          "/usr/local/bin/mutool",
                          "/usr/bin/mutool"].compactMap { $0 }
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw XCTSkip("mutool không có trên máy này")
        }
        guard let version = installedMutoolVersion(at: path), isAtLeast124(version) else {
            throw XCTSkip("mutool ở \(path) thiếu phiên bản hoặc cũ hơn 1.24 (annotation JS dùng ES module)")
        }
        return MuPDFDocumentEngine(executableURL: URL(fileURLWithPath: path))
    }

    private func installedMutoolVersion(at path: String) -> (major: Int, minor: Int)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-v"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard let match = output.range(of: #"([0-9]+)\.([0-9]+)"#, options: .regularExpression) else { return nil }
        let parts = output[match].split(separator: ".")
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        return (major, minor)
    }

    private func isAtLeast124(_ version: (major: Int, minor: Int)) -> Bool {
        version.major > 1 || (version.major == 1 && version.minor >= 24)
    }

    func testMuPDFOperationMatrixBaseline() throws {
        let engine = try makeEngine()
        let data = try Data(contentsOf: fixtureURL)

        let report = PDFEngineOperationConformance.run(engine, data: data, auxiliaryPDF: data, imagePNG: imagePNG)

        let expectedSupported: Set<String> = ["upsertAnnotation", "upsertImageAnnotation", "removeAnnotation"]
        XCTAssertTrue(
            report.supportedOperations.isSuperset(of: expectedSupported),
            "MuPDF phải hỗ trợ tối thiểu \(expectedSupported), thực tế supported: \(report.supportedOperations). " +
            "Chi tiết: \(report.results)"
        )

        let unexpectedlySupported = report.supportedOperations.subtracting(expectedSupported)
        XCTAssertTrue(
            unexpectedlySupported.isEmpty,
            "Case ngoài baseline hiện đã supported trên MuPDF — cập nhật ma trận 1e nếu đúng: \(unexpectedlySupported)"
        )

        XCTAssertTrue(report.failedOperations.isEmpty, "Không case nào được phép .failed: \(report.failedOperations)")
    }
}
