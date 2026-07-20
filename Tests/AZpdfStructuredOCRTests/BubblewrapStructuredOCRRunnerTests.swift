import Foundation
import XCTest
@testable import AZpdfStructuredOCR

final class BubblewrapStructuredOCRRunnerTests: XCTestCase {
    func testBuildsNetworkIsolatedRecognizeInvocation() throws {
        let provider = try makeExecutable(name: "provider")
        let input = try makeFile(name: "input.pdf", data: Data("%PDF-fixture".utf8))
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("azpdf-bwrap-work-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: work) }
        let request = work.appendingPathComponent("request.json")
        try Data("{}".utf8).write(to: request)
        let output = work.appendingPathComponent("document-ir.json")

        let runner = BubblewrapStructuredOCRRunner(
            bubblewrapURL: try makeExecutable(name: "bwrap"),
            systemReadOnlyPaths: [],
            launcher: RecordingRunner()
        )
        let arguments = try runner.sandboxInvocation(
            executable: provider,
            arguments: [
                "recognize",
                "--input", input.path,
                "--request", request.path,
                "--output", output.path
            ]
        )

        XCTAssertTrue(arguments.contains("--unshare-net"))
        XCTAssertTrue(arguments.contains("--clearenv"))
        XCTAssertTrue(arguments.containsSubsequence(["--bind", work.path, "/work"]))
        XCTAssertTrue(arguments.containsSubsequence(["--ro-bind", input.path, "/input/document.pdf"]))
        XCTAssertTrue(arguments.containsSubsequence(["--ro-bind", request.path, "/work/request.json"]))
        XCTAssertTrue(arguments.containsSubsequence(["--input", "/input/document.pdf"]))
        XCTAssertTrue(arguments.containsSubsequence(["--request", "/work/request.json"]))
        XCTAssertTrue(arguments.containsSubsequence(["--output", "/work/document-ir.json"]))
        XCTAssertTrue(arguments.containsSubsequence([
            "--",
            "/app/provider/\(provider.lastPathComponent)",
            "recognize"
        ]))
    }

    func testBuildsCapabilitiesInvocationWithoutDocumentMount() throws {
        let runner = BubblewrapStructuredOCRRunner(
            bubblewrapURL: try makeExecutable(name: "bwrap"),
            systemReadOnlyPaths: [],
            launcher: RecordingRunner()
        )
        let arguments = try runner.sandboxInvocation(
            executable: try makeExecutable(name: "provider"),
            arguments: ["capabilities", "--format", "json"]
        )

        XCTAssertFalse(arguments.contains("/input/document.pdf"))
        XCTAssertTrue(arguments.containsSubsequence(["capabilities", "--format", "json"]))
    }

    func testRejectsUnknownOrIncompleteInvocation() throws {
        let runner = BubblewrapStructuredOCRRunner(
            bubblewrapURL: try makeExecutable(name: "bwrap"),
            systemReadOnlyPaths: [],
            launcher: RecordingRunner()
        )
        let provider = try makeExecutable(name: "provider")

        XCTAssertThrowsError(try runner.sandboxInvocation(executable: provider, arguments: ["unknown"])) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .invalidInvocation)
        }
        XCTAssertThrowsError(try runner.sandboxInvocation(
            executable: provider,
            arguments: ["recognize", "--input", "/missing"]
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .invalidInvocation)
        }
    }

    func testReportsUbuntuNamespacePolicyFailureAsSandboxUnavailable() throws {
        #if !os(Linux)
        throw XCTSkip("Bubblewrap runner chỉ thực thi trên Linux.")
        #else
        let runner = BubblewrapStructuredOCRRunner(
            bubblewrapURL: try makeExecutable(name: "bwrap"),
            systemReadOnlyPaths: [],
            launcher: FixedResultRunner(.init(
                status: 1,
                standardError: Data("bwrap: setting up uid map: Permission denied\n".utf8)
            ))
        )

        XCTAssertThrowsError(try runner.run(
            executable: try makeExecutable(name: "provider"),
            arguments: ["capabilities", "--format", "json"]
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .sandboxUnavailable)
        }
        #endif
    }

    func testDoesNotHideProviderFailureAsSandboxFailure() throws {
        #if !os(Linux)
        throw XCTSkip("Bubblewrap runner chỉ thực thi trên Linux.")
        #else
        let expected = StructuredOCRCommandResult(
            status: 2,
            standardError: Data("Model weights are unavailable.\n".utf8)
        )
        let runner = BubblewrapStructuredOCRRunner(
            bubblewrapURL: try makeExecutable(name: "bwrap"),
            systemReadOnlyPaths: [],
            launcher: FixedResultRunner(expected)
        )

        XCTAssertEqual(try runner.run(
            executable: try makeExecutable(name: "provider"),
            arguments: ["capabilities", "--format", "json"]
        ), expected)
        #endif
    }

    private func makeExecutable(name: String) throws -> URL {
        #if os(Windows)
        return URL(fileURLWithPath: CommandLine.arguments[0])
        #else
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("azpdf-\(name)-\(UUID().uuidString)")
        _ = FileManager.default.createFile(atPath: url.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
        #endif
    }

    private func makeFile(name: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("azpdf-\(UUID().uuidString)-\(name)")
        try data.write(to: url, options: .atomic)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}

private struct RecordingRunner: StructuredOCRProcessRunning {
    let networkIsolation: StructuredOCRNetworkIsolation = .none

    func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        .init(status: 0)
    }
}

private struct FixedResultRunner: StructuredOCRProcessRunning {
    let networkIsolation: StructuredOCRNetworkIsolation = .none
    let result: StructuredOCRCommandResult

    init(_ result: StructuredOCRCommandResult) {
        self.result = result
    }

    func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        result
    }
}

private extension Array where Element: Equatable {
    func containsSubsequence(_ subsequence: [Element]) -> Bool {
        guard !subsequence.isEmpty, subsequence.count <= count else { return false }
        return indices.contains { start in
            let end = start + subsequence.count
            return end <= count && Array(self[start..<end]) == subsequence
        }
    }
}
