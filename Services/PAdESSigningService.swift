import Foundation

enum PAdESSigningError: LocalizedError {
    case signingRuntimeUnavailable
    case verificationRuntimeUnavailable
    case signingFailed(String)
    case verificationFailed(String)
    case timestampURLRequired

    var errorDescription: String? {
        switch self {
        case .signingRuntimeUnavailable:
            "Chưa có PAdES runtime. Bản phát hành AZpdf phải đi kèm pyHanko runtime đã đóng gói."
        case .verificationRuntimeUnavailable:
            "Chưa có PAdES runtime. Bản phát hành AZpdf phải đi kèm pyHanko runtime đã đóng gói."
        case let .signingFailed(message):
            "Không thể ký PAdES: \(message)"
        case let .verificationFailed(message):
            "Không thể xác minh PAdES: \(message)"
        case .timestampURLRequired:
            "PAdES-LT/LTA cần URL TSA RFC 3161 hợp lệ để lấy timestamp tin cậy."
        }
    }
}

enum PAdESProfile: String, CaseIterable, Identifiable, Sendable {
    case baselineB
    case baselineLT
    case baselineLTA

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .baselineB: "PAdES Baseline B (offline)"
        case .baselineLT: "PAdES Baseline LT"
        case .baselineLTA: "PAdES Baseline LTA"
        }
    }
    var requiresTimestamp: Bool { self != .baselineB }
}

struct PAdESVerification: Equatable {
    enum Integrity: Equatable {
        case valid
        case invalid
        case unsigned
        case unknown
    }

    enum CertificateTrust: Equatable {
        case trusted
        case untrusted
        case unknown
    }

    let integrity: Integrity
    let certificateTrust: CertificateTrust
    let signerName: String?
    let details: String
    let hasTimestamp: Bool
    let hasValidationInfo: Bool

    var summary: String {
        let integrityMessage = switch integrity {
        case .valid: "Tính toàn vẹn chữ ký: hợp lệ."
        case .invalid: "Tính toàn vẹn chữ ký: không hợp lệ."
        case .unsigned: "PDF không có chữ ký số nhúng."
        case .unknown: "Không xác định được tính toàn vẹn chữ ký."
        }
        let trustMessage = switch certificateTrust {
        case .trusted: "Certificate: được tin cậy trên máy này."
        case .untrusted: "Certificate: chưa được tin cậy trên máy này."
        case .unknown: "Certificate: không xác định được trạng thái tin cậy."
        }
        let evidence = hasTimestamp
            ? "Có timestamp trong tài liệu."
            : "Chưa phát hiện timestamp trong kết quả validator."
        let validationInfo = hasValidationInfo
            ? "Có dữ liệu validation/DSS."
            : "Chưa phát hiện dữ liệu validation/DSS."
        return [integrityMessage, trustMessage, evidence, validationInfo, signerName.map { "Người ký: \($0)." }]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

/// Uses bundled local tools only. The P12 password is written to a private
/// temporary file because pyHanko supports passfiles; it is never sent as a
/// process argument or persisted by AZpdf.
enum PAdESSigningService {
    static let defaultFieldSpec = "1/36,36,260,96/AZpdfSignature"

    static func sign(
        documentData: Data,
        pkcs12Data: Data,
        password: String,
        fieldSpec: String = defaultFieldSpec,
        profile: PAdESProfile = .baselineB,
        timestampURL: String? = nil,
        executable explicitExecutable: URL? = nil
    ) throws -> Data {
        guard let executable = explicitExecutable ?? signingRuntimeURL() else {
            throw PAdESSigningError.signingRuntimeUnavailable
        }
        let directory = try temporaryDirectory(named: "AZpdf-PAdES")
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appending(path: "input.pdf")
        let output = directory.appending(path: "signed.pdf")
        let certificate = directory.appending(path: "signer.p12")
        let passwordFile = directory.appending(path: "password.txt")
        try documentData.write(to: input, options: .atomic)
        try pkcs12Data.write(to: certificate, options: .atomic)
        try Data(password.utf8).write(to: passwordFile, options: .atomic)
        try secureFile(certificate)
        try secureFile(passwordFile)

        var arguments = ["sign", "addsig", "--field", fieldSpec, "--use-pades"]
        if profile.requiresTimestamp {
            guard let timestampURL, URL(string: timestampURL)?.scheme?.hasPrefix("http") == true else {
                throw PAdESSigningError.timestampURLRequired
            }
            arguments += ["--timestamp-url", timestampURL, "--with-validation-info"]
            if profile == .baselineLTA { arguments.append("--use-pades-lta") }
        }
        arguments += ["pkcs12", "--passfile", passwordFile.path, input.path, output.path, certificate.path]
        let result = try run(executable, arguments: arguments)
        guard result.status == 0, FileManager.default.fileExists(atPath: output.path) else {
            throw PAdESSigningError.signingFailed(result.message)
        }
        return try Data(contentsOf: output)
    }

    static func verify(
        documentData: Data,
        executable explicitExecutable: URL? = nil
    ) throws -> PAdESVerification {
        guard let executable = explicitExecutable ?? signingRuntimeURL() else {
            throw PAdESSigningError.verificationRuntimeUnavailable
        }
        let directory = try temporaryDirectory(named: "AZpdf-PAdES-Verify")
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appending(path: "input.pdf")
        try documentData.write(to: input, options: .atomic)
        // pyHanko returns a non-zero exit code for an untrusted certificate,
        // even when the PDF signature itself is cryptographically sound.
        let result = try run(executable, arguments: ["sign", "validate", "--pretty-print", "--no-revocation-check", input.path])
        let details = result.message
        guard !details.isEmpty else { throw PAdESSigningError.verificationFailed("Trình xác minh không trả kết quả.") }
        return PAdESVerification(
            integrity: integrity(in: details),
            certificateTrust: trust(in: details),
            signerName: capture("Certificate subject: \\\"?(.+?)\\\"?$", in: details),
            details: details,
            hasTimestamp: details.localizedCaseInsensitiveContains("timestamp"),
            hasValidationInfo: details.localizedCaseInsensitiveContains("validation info") || details.localizedCaseInsensitiveContains("document security store") || details.localizedCaseInsensitiveContains("dss")
        )
    }

    private static func integrity(in output: String) -> PAdESVerification.Integrity {
        if output.localizedCaseInsensitiveContains("signature is cryptographically sound") { return .valid }
        if output.localizedCaseInsensitiveContains("signature is cryptographically unsound") { return .invalid }
        if output.localizedCaseInsensitiveContains("does not contain any signatures") { return .unsigned }
        return .unknown
    }

    private static func trust(in output: String) -> PAdESVerification.CertificateTrust {
        if output.localizedCaseInsensitiveContains("signer's certificate is trusted") { return .trusted }
        if output.localizedCaseInsensitiveContains("signer's certificate is untrusted") { return .untrusted }
        return .unknown
    }

    private static func capture(_ pattern: String, in value: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func run(_ executable: URL, arguments: [String]) throws -> (status: Int32, message: String) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    private static func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        return directory
    }

    private static func secureFile(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func signingRuntimeURL() -> URL? {
        runtimeURL(bundleSubdirectory: "pyhanko", executable: "pyhanko")
    }

    private static func runtimeURL(bundleSubdirectory: String, executable: String) -> URL? {
        let candidates = [
            Bundle.main.bundleURL.appending(path: "Contents/Resources/Helpers/\(bundleSubdirectory)/\(executable)"),
            Bundle.main.url(forResource: executable, withExtension: nil, subdirectory: "Tools/\(bundleSubdirectory)"),
            URL(fileURLWithPath: "/opt/homebrew/bin/\(executable)"),
            URL(fileURLWithPath: "/usr/local/bin/\(executable)")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
