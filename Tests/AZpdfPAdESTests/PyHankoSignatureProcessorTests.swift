import XCTest
import AZpdfCore
@testable import AZpdfPAdES

final class PyHankoSignatureProcessorTests: XCTestCase {
    func testReportsCapabilitiesAndSeparatesIntegrityFromTrust() throws {
        let runner = MockPyHankoRunner()
        let processor = PyHankoSignatureProcessor(
            executableURL: URL(fileURLWithPath: "/usr/bin/pyhanko"),
            runner: runner
        )
        let input = try temporaryFile(name: "input.pdf", contents: "%PDF-test")
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let health = try processor.capabilities()
        let verification = try processor.verify(input: input)

        XCTAssertEqual(health.provider, "pyHanko")
        XCTAssertEqual(health.version, "0.32.1")
        XCTAssertEqual(health.profiles, PDFSignatureProfile.allCases)
        XCTAssertEqual(verification.integrity, .valid)
        XCTAssertEqual(verification.certificateTrust, .untrusted)
        XCTAssertEqual(verification.signerName, "CN=AZpdf Test")
    }

    func testSignsWithPassfileAndVerifiesOutput() throws {
        let runner = MockPyHankoRunner()
        let processor = PyHankoSignatureProcessor(
            executableURL: URL(fileURLWithPath: "/usr/bin/pyhanko"),
            runner: runner
        )
        let input = try temporaryFile(name: "input.pdf", contents: "%PDF-test")
        let directory = input.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("signed.pdf")
        let certificate = try write("certificate", to: directory.appendingPathComponent("signer.p12"))
        let passfile = try write("secret", to: directory.appendingPathComponent("password.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: passfile.path)

        let result = try processor.sign(
            PDFSignatureRequest(),
            input: input,
            output: output,
            pkcs12: certificate,
            passwordFile: passfile
        )

        XCTAssertEqual(result.profile, .baselineB)
        XCTAssertEqual(result.verification.integrity, .valid)
        XCTAssertEqual(try Data(contentsOf: output), Data("%PDF-test".utf8))
        let signingArguments = try XCTUnwrap(runner.invocations.first { $0.starts(with: ["sign", "addsig"]) })
        XCTAssertTrue(signingArguments.contains("--passfile"))
        XCTAssertFalse(signingArguments.contains("secret"))
    }

    func testTreatsSuccessfulEmptyValidationAsUnsigned() throws {
        let processor = PyHankoSignatureProcessor(
            executableURL: URL(fileURLWithPath: "/usr/bin/pyhanko"),
            runner: UnsignedPyHankoRunner()
        )
        let input = try temporaryFile(name: "input.pdf", contents: "%PDF-test")
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let verification = try processor.verify(input: input)

        XCTAssertEqual(verification.integrity, .unsigned)
        XCTAssertEqual(verification.certificateTrust, .unknown)
    }

    func testRejectsLTWithoutTimestampURL() throws {
        let runner = MockPyHankoRunner()
        let processor = PyHankoSignatureProcessor(
            executableURL: URL(fileURLWithPath: "/usr/bin/pyhanko"),
            runner: runner
        )
        let input = try temporaryFile(name: "input.pdf", contents: "%PDF-test")
        let directory = input.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: directory) }
        let certificate = try write("certificate", to: directory.appendingPathComponent("signer.p12"))
        let passfile = try write("secret", to: directory.appendingPathComponent("password.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: passfile.path)

        XCTAssertThrowsError(try processor.sign(
            PDFSignatureRequest(profile: .baselineLT),
            input: input,
            output: directory.appendingPathComponent("signed.pdf"),
            pkcs12: certificate,
            passwordFile: passfile
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("TSA"))
        }
    }

    func testRejectsWorldReadablePasswordFile() throws {
        #if os(Windows)
        throw XCTSkip("Windows does not expose POSIX permissions.")
        #else
        let processor = PyHankoSignatureProcessor(
            executableURL: URL(fileURLWithPath: "/usr/bin/pyhanko"),
            runner: MockPyHankoRunner()
        )
        let input = try temporaryFile(name: "input.pdf", contents: "%PDF-test")
        let directory = input.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: directory) }
        let certificate = try write("certificate", to: directory.appendingPathComponent("signer.p12"))
        let passfile = try write("secret", to: directory.appendingPathComponent("password.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: passfile.path)

        XCTAssertThrowsError(try processor.sign(
            PDFSignatureRequest(),
            input: input,
            output: directory.appendingPathComponent("signed.pdf"),
            pkcs12: certificate,
            passwordFile: passfile
        )) { error in
            XCTAssertEqual(error as? PyHankoSignatureError, .insecurePasswordFile)
        }
        #endif
    }

    func testInstalledPyHankoSignsAndDetectsTampering() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let executable = environment["AZPDF_PYHANKO"],
              let inputPath = environment["AZPDF_PADES_FIXTURE"],
              let certificatePath = environment["AZPDF_PADES_PKCS12"],
              let passwordPath = environment["AZPDF_PADES_PASSFILE"] else {
            throw XCTSkip("Set AZPDF_PYHANKO, AZPDF_PADES_FIXTURE, AZPDF_PADES_PKCS12 and AZPDF_PADES_PASSFILE.")
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AZpdf-PAdES-integration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("signed.pdf")
        let processor = PyHankoSignatureProcessor(
            executableURL: URL(fileURLWithPath: executable)
        )

        let result = try processor.sign(
            PDFSignatureRequest(),
            input: URL(fileURLWithPath: inputPath),
            output: output,
            pkcs12: URL(fileURLWithPath: certificatePath),
            passwordFile: URL(fileURLWithPath: passwordPath)
        )
        XCTAssertEqual(result.verification.integrity, .valid)

        var tampered = try Data(contentsOf: output)
        let marker = Data("Digitally signed by".utf8)
        let range = try XCTUnwrap(tampered.range(of: marker))
        tampered[range.lowerBound] = 0x45
        let tamperedURL = directory.appendingPathComponent("tampered.pdf")
        try tampered.write(to: tamperedURL, options: .atomic)

        XCTAssertEqual(try processor.verify(input: tamperedURL).integrity, .invalid)
    }

    private func temporaryFile(name: String, contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AZpdf-PAdES-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try write(contents, to: directory.appendingPathComponent(name))
    }

    @discardableResult
    private func write(_ value: String, to url: URL) throws -> URL {
        try Data(value.utf8).write(to: url, options: .atomic)
        return url
    }
}

private final class MockPyHankoRunner: PyHankoCommandRunning {
    var invocations: [[String]] = []

    func run(executable: URL, arguments: [String]) throws -> PyHankoCommandResult {
        invocations.append(arguments)
        if arguments == ["--version"] {
            return PyHankoCommandResult(
                status: 0,
                standardOutput: Data("pyHanko, version 0.32.1\n".utf8)
            )
        }
        if arguments.starts(with: ["sign", "addsig"]) {
            let input = URL(fileURLWithPath: arguments[arguments.count - 3])
            let output = URL(fileURLWithPath: arguments[arguments.count - 2])
            try FileManager.default.copyItem(at: input, to: output)
            return PyHankoCommandResult(status: 0)
        }
        if arguments.starts(with: ["sign", "validate"]) {
            return PyHankoCommandResult(
                status: 1,
                standardOutput: Data("""
                Certificate subject: \"CN=AZpdf Test\"
                The signer's certificate is untrusted.
                The signature is cryptographically sound.
                """.utf8)
            )
        }
        return PyHankoCommandResult(status: 2, standardError: Data("unexpected command".utf8))
    }
}

private struct UnsignedPyHankoRunner: PyHankoCommandRunning {
    func run(executable: URL, arguments: [String]) throws -> PyHankoCommandResult {
        PyHankoCommandResult(status: 0)
    }
}
