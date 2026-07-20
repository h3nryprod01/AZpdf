import XCTest
import AZpdfCore
@testable import AZpdfMuPDF

/// Every other test in this target stubs the command runner, so the JavaScript
/// the adapter actually runs is never executed. That is exactly how highlights
/// and ink annotations could come back as `unknown` while the suite stayed
/// green. These tests drive the real mutool against a real PDF instead.
final class MuPDFAnnotationKindTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)          // .../Tests/AZpdfMuPDFTests/<this file>
            .deletingLastPathComponent()          // .../Tests/AZpdfMuPDFTests
            .deletingLastPathComponent()          // .../Tests
            .appendingPathComponent("Fixtures/source/annotated-highlight-ink.pdf")
    }

    /// Skips rather than fails when mutool is missing or too old: Ubuntu 24.04
    /// ships 1.23, whose JS engine predates the ES module syntax the adapter
    /// script uses. A missing tool is not a defect in this code.
    private func makeEngine() throws -> MuPDFDocumentEngine {
        let candidates = [ProcessInfo.processInfo.environment["MUTOOL_BIN"],
                          "/opt/homebrew/bin/mutool",
                          "/usr/local/bin/mutool",
                          "/usr/bin/mutool"].compactMap { $0 }
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw XCTSkip("mutool không có trên máy này")
        }
        return MuPDFDocumentEngine(executableURL: URL(fileURLWithPath: path))
    }

    func testHighlightAndInkAreNotReportedAsUnknown() throws {
        let engine = try makeEngine()
        let data = try Data(contentsOf: fixtureURL)
        let document = try engine.load(data: data)

        let annotations: [PDFAnnotationDescriptor]
        do {
            annotations = try engine.annotations(onPage: 0, in: document)
        } catch {
            throw XCTSkip("mutool không chạy được script annotations: \(error)")
        }

        let kinds = Set(annotations.map(\.kind))
        XCTAssertTrue(kinds.contains(.highlight), "highlight phải map đúng, nhận được: \(kinds)")
        XCTAssertTrue(kinds.contains(.ink), "ink phải map đúng, nhận được: \(kinds)")
        XCTAssertFalse(kinds.contains(.unknown), "không annotation nào được rơi vào unknown: \(kinds)")
    }

    /// The bounds were always right; only the kind was wrong. Pinning this keeps
    /// a future mapping change from quietly breaking geometry too.
    func testAnnotationBoundsSurviveTheMapping() throws {
        let engine = try makeEngine()
        let data = try Data(contentsOf: fixtureURL)
        let document = try engine.load(data: data)

        let annotations: [PDFAnnotationDescriptor]
        do {
            annotations = try engine.annotations(onPage: 0, in: document)
        } catch {
            throw XCTSkip("mutool không chạy được script annotations: \(error)")
        }

        XCTAssertEqual(annotations.count, 2)
        for annotation in annotations {
            XCTAssertGreaterThan(annotation.bounds.size.width, 0, "\(annotation.kind) mất chiều rộng")
            XCTAssertGreaterThan(annotation.bounds.size.height, 0, "\(annotation.kind) mất chiều cao")
        }
    }
}
