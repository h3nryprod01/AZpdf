import Foundation
import Security

struct CertificateIdentity: Identifiable {
    let id: String
    let displayName: String
    fileprivate let identity: SecIdentity
}

enum CertificateSigningError: LocalizedError {
    case noIdentity
    case security(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noIdentity:
            "Không tìm thấy certificate ký trong Keychain. Hãy cài certificate có private key trước."
        case let .security(status):
            (SecCopyErrorMessageString(status, nil) as String?) ?? "Lỗi Security.framework: \(status)."
        }
    }
}

/// Creates a CMS/PKCS#7 detached signature. The PDF bytes themselves are not changed.
enum CertificateSigningService {
    static func availableIdentities() throws -> [CertificateIdentity] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { throw CertificateSigningError.noIdentity }
        guard status == errSecSuccess else { throw CertificateSigningError.security(status) }
        let identities = (result as? [SecIdentity]) ?? []
        let certificates = identities.compactMap { identity -> CertificateIdentity? in
            var certificate: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
                  let certificate else { return nil }
            let name = (SecCertificateCopySubjectSummary(certificate) as String?) ?? "Certificate không tên"
            let id = SecCertificateCopyData(certificate) as Data
            return CertificateIdentity(id: id.base64EncodedString(), displayName: name, identity: identity)
        }
        guard !certificates.isEmpty else { throw CertificateSigningError.noIdentity }
        return certificates.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    static func detachedSignature(for data: Data, identity: CertificateIdentity) throws -> Data {
        var encoder: CMSEncoder?
        try check(CMSEncoderCreate(&encoder))
        guard let encoder else { throw CertificateSigningError.noIdentity }
        try check(CMSEncoderAddSigners(encoder, identity.identity))
        try check(CMSEncoderSetHasDetachedContent(encoder, true))
        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { throw CertificateSigningError.security(errSecParam) }
            try check(CMSEncoderUpdateContent(encoder, baseAddress, data.count))
        }
        var encoded: CFData?
        try check(CMSEncoderCopyEncodedContent(encoder, &encoded))
        guard let encoded else { throw CertificateSigningError.noIdentity }
        return encoded as Data
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw CertificateSigningError.security(status) }
    }
}
