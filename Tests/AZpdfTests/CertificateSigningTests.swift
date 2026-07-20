import Foundation
import Security
import XCTest
@testable import AZpdf

/// Exercises the real CMS/PKCS#7 signing path end to end.
///
/// Signing with an identity from the login Keychain makes macOS raise a
/// SecurityAgent prompt that only the machine's owner can approve, so that
/// route cannot be automated — and should not be. Instead this builds a
/// throwaway self-signed identity and imports it with `kSecImportToMemoryOnly`,
/// which yields a usable `SecIdentity` without creating a keychain, touching
/// the user's keychain, or triggering any prompt.
final class CertificateSigningTests: XCTestCase {

    func testDetachedSignatureIsValidCMSAndOnlyVerifiesAgainstTheSignedBytes() throws {
        let identity = try makeThrowawayIdentity()
        let document = Data("%PDF-1.7 AZpdf detached signature test\n".utf8)

        let signature = try CertificateSigningService.detachedSignature(for: document, identity: identity)

        XCTAssertFalse(signature.isEmpty)
        try assertIsDetachedCMS(signature)

        // Correct bytes. The identity is self-signed and deliberately not in any
        // trust store, so the expected outcome is invalidCertificate — the
        // status that means "signature matches the data, but the certificate is
        // not trusted". Getting invalidSignature here would mean integrity
        // checking is broken; getting valid would mean an untrusted certificate
        // was waved through.
        let match = try CertificateSigningService.verifyDetachedSignature(signature, documentData: document)
        XCTAssertEqual(match.status, .invalidCertificate,
                       "integrity phải đạt, trust phải trượt — không được gộp làm một")
        XCTAssertEqual(match.signerName, "AZpdf QA Test Identity")

        // Tampered bytes must fail on integrity, a different status entirely.
        // A detached signature that still passed after the document changed
        // would be worse than having no signature at all.
        var tampered = document
        tampered.append(contentsOf: Data(" tampered".utf8))
        let mismatch = try CertificateSigningService.verifyDetachedSignature(signature, documentData: tampered)
        XCTAssertEqual(mismatch.status, .invalidSignature,
                       "sửa nội dung phải bị bắt ở tầng integrity")
    }

    func testVerifyingAFileThatIsNotASignatureThrows() {
        XCTAssertThrowsError(
            try CertificateSigningService.verifyDetachedSignature(
                Data("day khong phai chu ky".utf8),
                documentData: Data("%PDF".utf8)
            )
        )
    }

    // MARK: - Helpers

    /// Confirms the blob really is PKCS#7 signed-data with detached content,
    /// using `openssl` rather than the same Security framework that produced it.
    private func assertIsDetachedCMS(_ signature: Data) throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "azpdf-sig-\(UUID().uuidString).p7s")
        try signature.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let output = try run("/usr/bin/openssl", ["pkcs7", "-inform", "DER", "-in", url.path, "-print_certs", "-noout"])
        XCTAssertTrue(output.contains("AZpdf QA"), "openssl phải đọc được certificate trong .p7s:\n\(output)")
    }

    private func makeThrowawayIdentity() throws -> CertificateIdentity {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "azpdf-cert-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let key = directory.appending(path: "key.pem").path
        let cert = directory.appending(path: "cert.pem").path
        let bundle = directory.appending(path: "identity.p12").path
        let passphrase = "azpdf-test"

        _ = try run("/usr/bin/openssl", [
            "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-days", "1", "-nodes",
            "-keyout", key, "-out", cert, "-subj", "/CN=AZpdf QA Test Identity"
        ])
        // No -legacy: macOS ships LibreSSL, which does not accept that flag.
        _ = try run("/usr/bin/openssl", [
            "pkcs12", "-export", "-inkey", key, "-in", cert,
            "-out", bundle, "-passout", "pass:\(passphrase)"
        ])

        // Importing to memory keeps this out of any keychain — that is what
        // avoids the SecurityAgent prompt. The package deploys to macOS 14, so
        // on older systems there is no prompt-free route and the test skips
        // rather than silently signing with something else.
        guard #available(macOS 15.0, *) else {
            throw XCTSkip("kSecImportToMemoryOnly cần macOS 15+; không có đường import không-keychain")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: bundle))
        var items: CFArray?
        let status = SecPKCS12Import(
            data as CFData,
            [kSecImportExportPassphrase as String: passphrase,
             kSecImportToMemoryOnly as String: true] as CFDictionary,
            &items
        )
        guard status == errSecSuccess,
              let entries = items as? [[String: Any]],
              let first = entries.first,
              let identityRef = first[kSecImportItemIdentity as String] else {
            throw XCTSkip("Không tạo được identity tạm (SecPKCS12Import status \(status))")
        }

        // swiftlint:disable:next force_cast
        let secIdentity = identityRef as! SecIdentity
        return CertificateIdentity(id: "test", displayName: "AZpdf QA Test Identity", identity: secIdentity)
    }

    @discardableResult
    private func run(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: output, as: UTF8.self)
        if process.terminationStatus != 0 {
            throw NSError(domain: "azpdf.test", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(launchPath) lỗi:\n\(text)"])
        }
        return text
    }
}
