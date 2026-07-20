import Foundation
import XCTest
@testable import AZpdfStructuredOCR

final class FlatpakSpawnStructuredOCRRunnerTests: XCTestCase {
    func testBuildsTightCapabilitiesInvocationWithoutHostEscape() throws {
        let fixture = try makeFixture()
        let runner = makeRunner(fixture: fixture, launcher: RecordingRunner())

        let invocation = try runner.prepareInvocation(
            executable: fixture.provider,
            arguments: ["capabilities", "--format", "json"],
            token: "capabilities"
        )
        defer { invocation.cleanup() }

        XCTAssertTrue(invocation.arguments.containsSubsequence([
            "--sandbox", "--no-network", "--clear-env", "--watch-bus"
        ]))
        XCTAssertFalse(invocation.arguments.contains("--host"))
        XCTAssertTrue(invocation.arguments.containsSubsequence([
            "--", fixture.provider.path, "capabilities", "--format", "json"
        ]))
        XCTAssertTrue(invocation.cleanupURLs.isEmpty)
    }

    func testStagesRecognizeFilesWithLeastPrivilegeExposePolicy() throws {
        let fixture = try makeFixture()
        let input = try makeFile(name: "input.pdf", data: Data("%PDF-fixture".utf8))
        let request = try makeFile(name: "request.json", data: Data("{}".utf8))
        let outputDirectory = try makeDirectory(name: "output")
        let output = outputDirectory.appendingPathComponent("document-ir.json")
        let runner = makeRunner(fixture: fixture, launcher: RecordingRunner())

        let invocation = try runner.prepareInvocation(
            executable: fixture.provider,
            arguments: [
                "recognize",
                "--input", input.path,
                "--request", request.path,
                "--output", output.path
            ],
            token: "fixture"
        )
        defer { invocation.cleanup() }

        let stagedInput = fixture.sandbox.appendingPathComponent("azpdf-input-fixture.pdf")
        let stagedRequest = fixture.sandbox.appendingPathComponent("azpdf-request-fixture.json")
        let stagedWork = fixture.sandbox.appendingPathComponent("azpdf-work-fixture")
        XCTAssertEqual(try Data(contentsOf: stagedInput), Data("%PDF-fixture".utf8))
        XCTAssertEqual(try Data(contentsOf: stagedRequest), Data("{}".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedWork.path))
        XCTAssertTrue(invocation.arguments.contains("--sandbox-expose-ro=azpdf-input-fixture.pdf"))
        XCTAssertTrue(invocation.arguments.contains("--sandbox-expose-ro=azpdf-request-fixture.json"))
        XCTAssertTrue(invocation.arguments.contains("--sandbox-expose=azpdf-work-fixture"))
        XCTAssertFalse(invocation.arguments.contains("--host"))
        XCTAssertTrue(invocation.arguments.containsSubsequence(["--input", stagedInput.path]))
        XCTAssertTrue(invocation.arguments.containsSubsequence(["--request", stagedRequest.path]))
        XCTAssertTrue(invocation.arguments.containsSubsequence([
            "--output", stagedWork.appendingPathComponent("document-ir.json").path
        ]))
    }

    func testRejectsProviderOutsidePackagedAppAndUnsafeInvocation() throws {
        let fixture = try makeFixture()
        let runner = makeRunner(fixture: fixture, launcher: RecordingRunner())

        XCTAssertThrowsError(try runner.prepareInvocation(
            executable: try makeExecutable(in: FileManager.default.temporaryDirectory, name: "outside-provider"),
            arguments: ["capabilities"],
            token: "fixture"
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .runtimeUnavailable)
        }
        XCTAssertThrowsError(try runner.prepareInvocation(
            executable: fixture.provider,
            arguments: ["unknown"],
            token: "fixture"
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .invalidInvocation)
        }
        XCTAssertThrowsError(try runner.prepareInvocation(
            executable: fixture.provider,
            arguments: ["capabilities"],
            token: "../escape"
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .invalidInvocation)
        }
    }

    func testCopiesSuccessfulProviderOutputAndCleansStage() throws {
        #if !os(Linux)
        throw XCTSkip("Flatpak runner chỉ thực thi trên Linux.")
        #else
        let fixture = try makeFixture()
        let flatpakSpawn = try makeExecutable(in: fixture.root, name: "flatpak-spawn")
        let input = try makeFile(name: "input.pdf", data: Data("%PDF-fixture".utf8))
        let request = try makeFile(name: "request.json", data: Data("{}".utf8))
        let outputDirectory = try makeDirectory(name: "output")
        let output = outputDirectory.appendingPathComponent("document-ir.json")
        let payload = Data("{\"schemaVersion\":1}".utf8)
        let runner = FlatpakSpawnStructuredOCRRunner(
            flatpakSpawnURL: flatpakSpawn,
            appRootURL: fixture.app,
            instanceSandboxURL: fixture.sandbox,
            flatpakID: "org.azpdf.AZpdf",
            launcher: OutputWritingRunner(payload: payload)
        )

        XCTAssertEqual(try runner.run(
            executable: fixture.provider,
            arguments: [
                "recognize",
                "--input", input.path,
                "--request", request.path,
                "--output", output.path
            ]
        ).status, 0)
        XCTAssertEqual(try Data(contentsOf: output), payload)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: fixture.sandbox.path),
            []
        )
        #endif
    }

    func testReportsPortalFailureAsSandboxUnavailable() throws {
        #if !os(Linux)
        throw XCTSkip("Flatpak runner chỉ thực thi trên Linux.")
        #else
        let fixture = try makeFixture()
        let runner = FlatpakSpawnStructuredOCRRunner(
            flatpakSpawnURL: try makeExecutable(in: fixture.root, name: "flatpak-spawn"),
            appRootURL: fixture.app,
            instanceSandboxURL: fixture.sandbox,
            flatpakID: "org.azpdf.AZpdf",
            launcher: FixedResultRunner(.init(
                status: 1,
                standardError: Data("Portal call failed: org.freedesktop.portal.Flatpak unavailable\n".utf8)
            ))
        )

        XCTAssertThrowsError(try runner.run(
            executable: fixture.provider,
            arguments: ["capabilities", "--format", "json"]
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .sandboxUnavailable)
        }
        #endif
    }

    private func makeRunner(
        fixture: Fixture,
        launcher: any StructuredOCRProcessRunning
    ) -> FlatpakSpawnStructuredOCRRunner {
        FlatpakSpawnStructuredOCRRunner(
            flatpakSpawnURL: fixture.root.appendingPathComponent("flatpak-spawn"),
            appRootURL: fixture.app,
            instanceSandboxURL: fixture.sandbox,
            flatpakID: "org.azpdf.AZpdf",
            launcher: launcher
        )
    }

    private func makeFixture() throws -> Fixture {
        let root = try makeDirectory(name: "flatpak-fixture")
        let app = root.appendingPathComponent("app", isDirectory: true)
        let providerDirectory = app.appendingPathComponent("libexec", isDirectory: true)
        let sandbox = root.appendingPathComponent("sandbox", isDirectory: true)
        try FileManager.default.createDirectory(at: providerDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        return Fixture(
            root: root,
            app: app,
            sandbox: sandbox,
            provider: try makeExecutable(in: providerDirectory, name: "provider")
        )
    }

    private func makeDirectory(name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("azpdf-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func makeExecutable(in directory: URL, name: String) throws -> URL {
        #if os(Windows)
        return URL(fileURLWithPath: CommandLine.arguments[0])
        #else
        let url = directory.appendingPathComponent("\(name)-\(UUID().uuidString)")
        _ = FileManager.default.createFile(atPath: url.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
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

private struct Fixture {
    let root: URL
    let app: URL
    let sandbox: URL
    let provider: URL
}

private struct RecordingRunner: StructuredOCRProcessRunning {
    let networkIsolation: StructuredOCRNetworkIsolation = .none

    func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        .init(status: 0)
    }
}

private struct OutputWritingRunner: StructuredOCRProcessRunning {
    let networkIsolation: StructuredOCRNetworkIsolation = .none
    let payload: Data

    func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        guard let outputIndex = arguments.firstIndex(of: "--output"),
              arguments.indices.contains(outputIndex + 1) else {
            return .init(status: 2, standardError: Data("missing output".utf8))
        }
        try payload.write(to: URL(fileURLWithPath: arguments[outputIndex + 1]), options: .atomic)
        return .init(status: 0)
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
