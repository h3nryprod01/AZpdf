import Foundation
import Dispatch
import Subprocess
import AZpdfCore

public enum PyHankoSignatureError: LocalizedError, Equatable {
    case invalidRequest(String)
    case insecurePasswordFile
    case signingFailed(String)
    case verificationFailed(String)
    case invalidSignedOutput

    public var errorDescription: String? {
        switch self {
        case let .invalidRequest(message):
            "Yêu cầu PAdES không hợp lệ: \(message)"
        case .insecurePasswordFile:
            "File mật khẩu PKCS#12 phải chỉ cho chủ sở hữu đọc/ghi (chmod 600)."
        case let .signingFailed(message):
            "Không thể ký PAdES: \(message)"
        case let .verificationFailed(message):
            "Không thể xác minh PAdES: \(message)"
        case .invalidSignedOutput:
            "pyHanko đã tạo file nhưng không xác minh được tính toàn vẹn chữ ký."
        }
    }
}

public struct PyHankoCommandResult: Equatable, Sendable {
    public let status: Int32
    public let standardOutput: Data
    public let standardError: Data

    public init(status: Int32, standardOutput: Data = Data(), standardError: Data = Data()) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public protocol PyHankoCommandRunning {
    func run(executable: URL, arguments: [String]) throws -> PyHankoCommandResult
}

public struct SubprocessPyHankoCommandRunner: PyHankoCommandRunning {
    public let timeout: TimeInterval
    public let maximumCapturedOutputBytes: Int

    public init(timeout: TimeInterval = 120, maximumCapturedOutputBytes: Int = 8 * 1_024 * 1_024) {
        self.timeout = max(0.1, timeout)
        self.maximumCapturedOutputBytes = max(1_024, maximumCapturedOutputBytes)
    }

    public func run(executable: URL, arguments: [String]) throws -> PyHankoCommandResult {
        let completion = PyHankoCommandCompletion()
        let semaphore = DispatchSemaphore(value: 0)
        let executablePath = executable.path
        let outputLimit = maximumCapturedOutputBytes
        let task = Task.detached(priority: .userInitiated) {
            do {
                var platformOptions = Subprocess.PlatformOptions()
                platformOptions.teardownSequence = [
                    .gracefulShutDown(allowedDurationToNextStep: .milliseconds(250))
                ]
                let result = try await Subprocess.run(
                    .path(.init(executablePath)),
                    arguments: Arguments(arguments),
                    platformOptions: platformOptions,
                    output: .data(limit: outputLimit),
                    error: .data(limit: outputLimit)
                )
                let status: Int32
                switch result.terminationStatus {
                case let .exited(code):
                    status = Int32(truncatingIfNeeded: code)
                #if !os(Windows)
                case let .signaled(signal):
                    status = 128 + Int32(signal)
                #endif
                }
                completion.store(.success(PyHankoCommandResult(
                    status: status,
                    standardOutput: result.standardOutput,
                    standardError: result.standardError
                )))
            } catch {
                completion.store(.failure(error))
            }
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            task.cancel()
            _ = semaphore.wait(timeout: .now() + 2)
            throw PDFEngineError.ioFailure("pyHanko vượt quá timeout \(timeout) giây.")
        }
        guard let result = completion.take() else {
            throw PDFEngineError.ioFailure("pyHanko kết thúc mà không trả kết quả.")
        }
        do {
            return try result.get()
        } catch {
            throw PDFEngineError.ioFailure("Không thể chạy pyHanko: \(String(describing: error))")
        }
    }
}

private final class PyHankoCommandCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<PyHankoCommandResult, Error>?

    func store(_ result: Result<PyHankoCommandResult, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func take() -> Result<PyHankoCommandResult, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

public struct PyHankoSignatureProcessor: PDFDigitalSignatureProcessor {
    public let executableURL: URL
    private let runner: any PyHankoCommandRunning

    public init(
        executableURL: URL,
        runner: any PyHankoCommandRunning = SubprocessPyHankoCommandRunner()
    ) {
        self.executableURL = executableURL
        self.runner = runner
    }

    public func capabilities() throws -> PDFSignatureCapabilities {
        let result = try runner.run(executable: executableURL, arguments: ["--version"])
        guard result.status == 0 else {
            throw PyHankoSignatureError.verificationFailed(
                message(from: result, fallback: "Không đọc được phiên bản pyHanko.")
            )
        }
        let version = message(from: result, fallback: "unknown")
            .replacingOccurrences(of: "pyHanko, version ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PDFSignatureCapabilities(
            provider: "pyHanko",
            version: version,
            executable: executableURL.path,
            profiles: PDFSignatureProfile.allCases
        )
    }

    public func verify(input: URL) throws -> PDFSignatureVerification {
        guard FileManager.default.fileExists(atPath: input.path) else {
            throw PyHankoSignatureError.invalidRequest("Không tìm thấy PDF cần xác minh.")
        }
        let result = try runner.run(
            executable: executableURL,
            arguments: ["sign", "validate", "--pretty-print", "--no-revocation-check", input.path]
        )
        let details = message(from: result, fallback: "")
        if details.isEmpty, result.status == 0 {
            return PDFSignatureVerification(
                integrity: .unsigned,
                certificateTrust: .unknown,
                details: "PDF không có chữ ký số nhúng."
            )
        }
        guard !details.isEmpty else {
            throw PyHankoSignatureError.verificationFailed("Trình xác minh không trả kết quả.")
        }
        return PDFSignatureVerification(
            integrity: integrity(in: details),
            certificateTrust: trust(in: details),
            signerName: capture(#"Certificate subject: \"?(.+?)\"?$"#, in: details),
            details: details,
            hasTimestamp: containsAny(["timestamp token", "document timestamp", "signature timestamp"], in: details),
            hasValidationInfo: containsAny(["validation info", "document security store", " dss", "/dss"], in: details)
        )
    }

    public func sign(
        _ request: PDFSignatureRequest,
        input: URL,
        output: URL,
        pkcs12: URL,
        passwordFile: URL
    ) throws -> PDFSignatureResult {
        try validate(request, input: input, output: output, pkcs12: pkcs12, passwordFile: passwordFile)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: output.path) { try fileManager.removeItem(at: output) }

        var arguments = ["sign", "addsig", "--field", request.fieldSpec, "--use-pades"]
        if request.profile.requiresTimestamp {
            guard let timestampURL = request.timestampURL else {
                throw PyHankoSignatureError.invalidRequest("PAdES-LT/LTA cần URL TSA RFC 3161.")
            }
            arguments += ["--timestamp-url", timestampURL, "--with-validation-info"]
            if request.profile == .baselineLTA { arguments.append("--use-pades-lta") }
        }
        arguments += [
            "pkcs12", "--passfile", passwordFile.path,
            input.path, output.path, pkcs12.path
        ]
        let result = try runner.run(executable: executableURL, arguments: arguments)
        guard result.status == 0,
              fileManager.fileExists(atPath: output.path),
              let size = try? fileManager.attributesOfItem(atPath: output.path)[.size] as? NSNumber,
              size.intValue > 0
        else {
            throw PyHankoSignatureError.signingFailed(
                message(from: result, fallback: "pyHanko không tạo được PDF đã ký.")
            )
        }
        let verification = try verify(input: output)
        guard verification.isCryptographicallyValid else {
            throw PyHankoSignatureError.invalidSignedOutput
        }
        let health = try capabilities()
        return PDFSignatureResult(
            provider: health.provider,
            version: health.version,
            profile: request.profile,
            output: output,
            bytes: size.intValue,
            verification: verification
        )
    }

    private func validate(
        _ request: PDFSignatureRequest,
        input: URL,
        output: URL,
        pkcs12: URL,
        passwordFile: URL
    ) throws {
        guard input.standardizedFileURL != output.standardizedFileURL else {
            throw PyHankoSignatureError.invalidRequest("PDF đầu ra phải khác file đầu vào.")
        }
        guard !request.fieldSpec.isEmpty,
              request.fieldSpec.count <= 512,
              !request.fieldSpec.contains("\n"),
              !request.fieldSpec.contains("\r") else {
            throw PyHankoSignatureError.invalidRequest("Field spec không hợp lệ.")
        }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: input.path),
              fileManager.fileExists(atPath: pkcs12.path),
              fileManager.fileExists(atPath: passwordFile.path) else {
            throw PyHankoSignatureError.invalidRequest("Thiếu PDF, PKCS#12 hoặc passfile.")
        }
        if request.profile.requiresTimestamp {
            guard let value = request.timestampURL,
                  let scheme = URL(string: value)?.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                throw PyHankoSignatureError.invalidRequest("URL TSA phải dùng HTTP hoặc HTTPS.")
            }
        }
        #if !os(Windows)
        if let attributes = try? fileManager.attributesOfItem(atPath: passwordFile.path),
           let permissions = attributes[.posixPermissions] as? NSNumber,
           permissions.intValue & 0o077 != 0 {
            throw PyHankoSignatureError.insecurePasswordFile
        }
        #endif
    }

    private func integrity(in value: String) -> PDFSignatureIntegrity {
        if containsAny(["signature is cryptographically unsound", "intact:failed", "intact:false"], in: value) {
            return .invalid
        }
        if containsAny(["signature is cryptographically sound", "intact:trusted", "intact:untrusted", "intact:true"], in: value) {
            return .valid
        }
        if containsAny(["does not contain any signatures", "no signatures found", "no signatures"], in: value) {
            return .unsigned
        }
        return .unknown
    }

    private func trust(in value: String) -> PDFCertificateTrust {
        if containsAny(["signer's certificate is untrusted", "intact:untrusted", "trusted:false"], in: value) {
            return .untrusted
        }
        if containsAny(["signer's certificate is trusted", "intact:trusted", "trusted:true"], in: value) {
            return .trusted
        }
        return .unknown
    }

    private func capture(_ pattern: String, in value: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ values: [String], in source: String) -> Bool {
        values.contains { source.localizedCaseInsensitiveContains($0) }
    }

    private func message(from result: PyHankoCommandResult, fallback: String) -> String {
        let values = [result.standardOutput, result.standardError]
            .map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? fallback : values.joined(separator: "\n")
    }
}
