import Foundation
import XCTest
import AZpdfCore
@testable import AZpdfStructuredOCR

final class StructuredOCRProcessProviderTests: XCTestCase {
    func testProductionRefusesUnisolatedRunner() throws {
        let executable = try makeExecutable()
        let runner = MockRunner(networkIsolation: .none) { _, _ in
            XCTFail("Không được chạy provider khi thiếu sandbox")
            return .init(status: 0)
        }
        let provider = StructuredOCRProcessProvider(executableURL: executable, runner: runner)

        XCTAssertThrowsError(try provider.capabilities()) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .sandboxRequired)
        }
    }

    func testReadsValidatedCapabilitiesFromIsolatedProvider() throws {
        let capabilities = makeCapabilities()
        let provider = StructuredOCRProcessProvider(
            executableURL: try makeExecutable(),
            runner: MockRunner(networkIsolation: .operatingSystemSandbox) { _, arguments in
                XCTAssertEqual(arguments, ["capabilities", "--format", "json"])
                return .init(status: 0, standardOutput: try JSONEncoder().encode(capabilities))
            }
        )

        XCTAssertEqual(try provider.capabilities(), capabilities)
    }

    func testRecognizeValidatesRequestOutputAndProvenance() throws {
        let capabilities = makeCapabilities()
        let document = makeDocument()
        let input = try makeInput()
        let runner = MockRunner(networkIsolation: .operatingSystemSandbox) { _, arguments in
            if arguments.first == "capabilities" {
                return .init(status: 0, standardOutput: try JSONEncoder().encode(capabilities))
            }
            XCTAssertEqual(arguments.first, "recognize")
            let requestURL = URL(fileURLWithPath: try XCTUnwrap(argumentValue(after: "--request", in: arguments)))
            let request = try JSONDecoder().decode(
                StructuredOCRRequest.self,
                from: Data(contentsOf: requestURL)
            )
            XCTAssertEqual(request.pageIndexes, [0])
            let output = URL(fileURLWithPath: try XCTUnwrap(argumentValue(after: "--output", in: arguments)))
            try DocumentIRCodec.encode(document).write(to: output, options: .atomic)
            return .init(status: 0)
        }
        let provider = StructuredOCRProcessProvider(executableURL: try makeExecutable(), runner: runner)

        let result = try provider.recognize(
            input: input,
            request: StructuredOCRRequest(
                pageIndexes: [0],
                languages: ["vi", "en"],
                requiredFeatures: [.text, .wordGeometry, .tables, .formulas]
            )
        )

        XCTAssertEqual(result, document)
    }

    func testRejectsUnsupportedRequestBeforeRecognition() throws {
        let capabilities = makeCapabilities()
        let runner = MockRunner(networkIsolation: .operatingSystemSandbox) { _, arguments in
            XCTAssertEqual(arguments.first, "capabilities")
            return .init(status: 0, standardOutput: try JSONEncoder().encode(capabilities))
        }
        let provider = StructuredOCRProcessProvider(executableURL: try makeExecutable(), runner: runner)

        XCTAssertThrowsError(try provider.recognize(
            input: try makeInput(),
            request: .init(languages: ["ja"])
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .unsupportedRequest)
        }
    }

    func testRejectsMismatchedProviderProvenance() throws {
        let capabilities = makeCapabilities()
        var document = makeDocument()
        document.provenance.providerID = "org.example.imposter"
        let runner = MockRunner(networkIsolation: .operatingSystemSandbox) { _, arguments in
            if arguments.first == "capabilities" {
                return .init(status: 0, standardOutput: try JSONEncoder().encode(capabilities))
            }
            let output = URL(fileURLWithPath: try XCTUnwrap(argumentValue(after: "--output", in: arguments)))
            try DocumentIRCodec.encode(document).write(to: output, options: .atomic)
            return .init(status: 0)
        }
        let provider = StructuredOCRProcessProvider(executableURL: try makeExecutable(), runner: runner)

        XCTAssertThrowsError(try provider.recognize(
            input: try makeInput(),
            request: StructuredOCRRequest(pageIndexes: [0], languages: ["vi", "en"])
        )) { error in
            XCTAssertEqual(error as? StructuredOCRProcessError, .provenanceMismatch)
        }
    }

    private func makeCapabilities() -> StructuredOCRProviderCapabilities {
        .init(
            providerID: "org.azpdf.paddleocr-vl",
            displayName: "PaddleOCR-VL",
            providerVersion: "1.0.0",
            modelID: "PaddleOCR-VL-1.6",
            modelVersion: "1.6",
            modelLicenseSPDX: "Apache-2.0",
            executionMode: .localProcessGPU,
            features: [.text, .wordGeometry, .readingOrder, .tables, .formulas, .figures],
            supportedLanguages: ["vi", "en"],
            minimumVRAMMiB: 8_192,
            maximumPagesPerRequest: 4
        )
    }

    private func makeDocument() -> DocumentIR {
        DocumentIR(
            provenance: .init(
                providerID: "org.azpdf.paddleocr-vl",
                providerVersion: "1.0.0",
                modelID: "PaddleOCR-VL-1.6",
                modelVersion: "1.6",
                languages: ["vi", "en"]
            ),
            pages: [
                .init(
                    index: 0,
                    size: PDFSize(width: 595, height: 842),
                    blocks: [
                        .init(
                            id: "p0-b0",
                            kind: .paragraph,
                            bounds: PDFRect(x: 40, y: 40, width: 200, height: 30),
                            text: "AZpdf structured OCR"
                        )
                    ],
                    readingOrder: ["p0-b0"]
                )
            ]
        )
    }

    private func makeExecutable() throws -> URL {
        #if os(Windows)
        return URL(fileURLWithPath: CommandLine.arguments[0])
        #else
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("azpdf-provider-\(UUID().uuidString)")
        _ = FileManager.default.createFile(atPath: url.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
        #endif
    }

    private func makeInput() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("azpdf-input-\(UUID().uuidString).pdf")
        try Data("%PDF-fixture".utf8).write(to: url, options: .atomic)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}

private final class MockRunner: StructuredOCRProcessRunning, @unchecked Sendable {
    let networkIsolation: StructuredOCRNetworkIsolation
    private let handler: (URL, [String]) throws -> StructuredOCRCommandResult

    init(
        networkIsolation: StructuredOCRNetworkIsolation,
        handler: @escaping (URL, [String]) throws -> StructuredOCRCommandResult
    ) {
        self.networkIsolation = networkIsolation
        self.handler = handler
    }

    func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        try handler(executable, arguments)
    }
}

private func argumentValue(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}
