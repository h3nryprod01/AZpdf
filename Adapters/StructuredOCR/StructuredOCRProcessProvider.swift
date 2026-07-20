import Dispatch
import Foundation
import Subprocess
import AZpdfCore

public enum StructuredOCRNetworkIsolation: String, Codable, Sendable {
    case none
    case operatingSystemSandbox
}

public struct StructuredOCRCommandResult: Equatable, Sendable {
    public let status: Int32
    public let standardOutput: Data
    public let standardError: Data

    public init(status: Int32, standardOutput: Data = Data(), standardError: Data = Data()) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public protocol StructuredOCRProcessRunning: Sendable {
    var networkIsolation: StructuredOCRNetworkIsolation { get }
    func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult
}

/// Development runner with timeout and bounded stdout/stderr. It does not claim
/// network isolation; production callers must wrap the provider in an OS sandbox.
public struct SubprocessStructuredOCRRunner: StructuredOCRProcessRunning {
    public let networkIsolation: StructuredOCRNetworkIsolation = .none
    public let timeout: TimeInterval
    public let maximumCapturedOutputBytes: Int

    public init(timeout: TimeInterval = 30 * 60, maximumCapturedOutputBytes: Int = 8 * 1_024 * 1_024) {
        self.timeout = max(0.1, timeout)
        self.maximumCapturedOutputBytes = max(1_024, maximumCapturedOutputBytes)
    }

    public func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        let completion = StructuredOCRCommandCompletion()
        let semaphore = DispatchSemaphore(value: 0)
        let outputLimit = maximumCapturedOutputBytes
        let executablePath = executable.path
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
                completion.store(.success(StructuredOCRCommandResult(
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
            throw StructuredOCRProcessError.timeout(timeout)
        }
        guard let result = completion.take() else {
            throw StructuredOCRProcessError.processFailed("Provider kết thúc mà không trả kết quả.")
        }
        do {
            return try result.get()
        } catch let error as StructuredOCRProcessError {
            throw error
        } catch {
            throw StructuredOCRProcessError.processFailed(String(describing: error))
        }
    }
}

public struct StructuredOCRProcessProvider {
    public let executableURL: URL
    public let maximumInputBytes: Int
    public let maximumOutputBytes: Int
    public let allowUnisolatedDevelopment: Bool

    private let runner: any StructuredOCRProcessRunning

    public init(
        executableURL: URL,
        runner: any StructuredOCRProcessRunning = SubprocessStructuredOCRRunner(),
        maximumInputBytes: Int = 2 * 1_024 * 1_024 * 1_024,
        maximumOutputBytes: Int = 256 * 1_024 * 1_024,
        allowUnisolatedDevelopment: Bool = false
    ) {
        self.executableURL = executableURL
        self.runner = runner
        self.maximumInputBytes = max(1, maximumInputBytes)
        self.maximumOutputBytes = max(1, maximumOutputBytes)
        self.allowUnisolatedDevelopment = allowUnisolatedDevelopment
    }

    public func capabilities() throws -> StructuredOCRProviderCapabilities {
        try validateRuntimeBoundary()
        let result = try runner.run(
            executable: executableURL,
            arguments: ["capabilities", "--format", "json"]
        )
        guard result.status == 0 else {
            throw StructuredOCRProcessError.capabilityFailed(message(from: result))
        }
        do {
            let capabilities = try JSONDecoder().decode(
                StructuredOCRProviderCapabilities.self,
                from: result.standardOutput
            )
            try capabilities.validate()
            return capabilities
        } catch let error as StructuredOCRContractError {
            throw StructuredOCRProcessError.capabilityFailed(error.localizedDescription)
        } catch {
            throw StructuredOCRProcessError.capabilityFailed(error.localizedDescription)
        }
    }

    public func recognize(input: URL, request: StructuredOCRRequest) throws -> DocumentIR {
        try validateRuntimeBoundary()
        try request.validate()
        try validateRegularInput(input)
        let capabilities = try capabilities()
        guard capabilities.supports(request) else {
            throw StructuredOCRProcessError.unsupportedRequest
        }

        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("AZpdf-StructuredOCR-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let requestURL = directory.appendingPathComponent("request.json")
        let outputURL = directory.appendingPathComponent("document-ir.json")
        let requestData = try JSONEncoder.sorted.encode(request)
        try requestData.write(to: requestURL, options: .atomic)
        #if !os(Windows)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: requestURL.path)
        #endif

        let result = try runner.run(
            executable: executableURL,
            arguments: [
                "recognize",
                "--input", input.path,
                "--request", requestURL.path,
                "--output", outputURL.path
            ]
        )
        guard result.status == 0 else {
            throw StructuredOCRProcessError.recognitionFailed(message(from: result))
        }

        let outputData = try readRegularOutput(outputURL)
        let document: DocumentIR
        do {
            document = try DocumentIRCodec.decodeAndValidate(outputData)
        } catch {
            throw StructuredOCRProcessError.invalidOutput(error.localizedDescription)
        }
        try validate(document: document, capabilities: capabilities, request: request)
        return document
    }

    private func validateRuntimeBoundary() throws {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw StructuredOCRProcessError.runtimeUnavailable
        }
        guard allowUnisolatedDevelopment || runner.networkIsolation == .operatingSystemSandbox else {
            throw StructuredOCRProcessError.sandboxRequired
        }
    }

    private func validateRegularInput(_ input: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: input.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0,
              size.intValue <= maximumInputBytes else {
            throw StructuredOCRProcessError.invalidInput
        }
    }

    private func readRegularOutput(_ output: URL) throws -> Data {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        } catch {
            throw StructuredOCRProcessError.invalidOutput("Provider không tạo output file.")
        }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0 else {
            throw StructuredOCRProcessError.invalidOutput("Provider không tạo regular output file.")
        }
        guard size.intValue <= maximumOutputBytes else {
            throw StructuredOCRProcessError.outputTooLarge(size.intValue)
        }
        return try Data(contentsOf: output, options: [.mappedIfSafe])
    }

    private func validate(
        document: DocumentIR,
        capabilities: StructuredOCRProviderCapabilities,
        request: StructuredOCRRequest
    ) throws {
        guard document.provenance.providerID == capabilities.providerID,
              document.provenance.providerVersion == capabilities.providerVersion,
              document.provenance.modelID == capabilities.modelID,
              document.provenance.modelVersion == capabilities.modelVersion else {
            throw StructuredOCRProcessError.provenanceMismatch
        }
        guard request.languages.allSatisfy(Set(document.provenance.languages).contains) else {
            throw StructuredOCRProcessError.provenanceMismatch
        }
        if let requestedPages = request.pageIndexes {
            guard Set(document.pages.map(\.index)) == Set(requestedPages) else {
                throw StructuredOCRProcessError.pageSetMismatch
            }
        }
    }

    private func message(from result: StructuredOCRCommandResult) -> String {
        let values = [result.standardError, result.standardOutput]
            .map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? "Provider trả exit status \(result.status)." : values.joined(separator: "\n")
    }
}

public enum StructuredOCRProcessError: Error, Equatable, Sendable {
    case runtimeUnavailable
    case sandboxUnavailable
    case sandboxRequired
    case invalidInvocation
    case timeout(TimeInterval)
    case invalidInput
    case capabilityFailed(String)
    case unsupportedRequest
    case recognitionFailed(String)
    case invalidOutput(String)
    case outputTooLarge(Int)
    case provenanceMismatch
    case pageSetMismatch
    case processFailed(String)
}

extension StructuredOCRProcessError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            "Không tìm thấy structured OCR provider executable."
        case .sandboxUnavailable:
            "Không tìm thấy hoặc không thể khởi động OS sandbox cho structured OCR."
        case .sandboxRequired:
            "Structured OCR provider bị từ chối vì chưa có network-isolated OS sandbox."
        case .invalidInvocation:
            "Structured OCR provider invocation không đúng protocol v1."
        case let .timeout(seconds):
            "Structured OCR provider vượt quá timeout \(seconds) giây."
        case .invalidInput:
            "Structured OCR input phải là regular file hợp lệ trong giới hạn dung lượng."
        case let .capabilityFailed(message):
            "Không đọc được capability structured OCR: \(message)"
        case .unsupportedRequest:
            "Provider không hỗ trợ language, feature hoặc số trang được yêu cầu."
        case let .recognitionFailed(message):
            "Structured OCR thất bại: \(message)"
        case let .invalidOutput(message):
            "Structured OCR output không hợp lệ: \(message)"
        case let .outputTooLarge(bytes):
            "Structured OCR output vượt giới hạn: \(bytes) byte."
        case .provenanceMismatch:
            "DocumentIR provenance không khớp provider/model đã xác minh."
        case .pageSetMismatch:
            "DocumentIR không chứa đúng tập trang đã yêu cầu."
        case let .processFailed(message):
            "Không thể chạy structured OCR provider: \(message)"
        }
    }
}

private final class StructuredOCRCommandCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<StructuredOCRCommandResult, Error>?

    func store(_ result: Result<StructuredOCRCommandResult, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func take() -> Result<StructuredOCRCommandResult, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
