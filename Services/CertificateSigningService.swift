import Foundation
import Security

struct CertificateIdentity: Identifiable {
    let id: String
    let displayName: String
    fileprivate let identity: SecIdentity
}

struct CertificateSignatureVerification: Equatable {
    enum Status: Equatable {
        case valid
        case invalidSignature
        case invalidCertificate
        case unsigned
        case unsupported
    }

    let status: Status
    let signerName: String?

    var summary: String {
        let signer = signerName.map { "Người ký: \($0). " } ?? ""
        return switch status {
        case .valid: "\(signer)Chữ ký hợp lệ và certificate được hệ thống tin cậy."
        case .invalidSignature: "\(signer)Chữ ký không khớp với PDF đang mở hoặc dữ liệu chữ ký đã bị thay đổi."
        case .invalidCertificate: "\(signer)Chữ ký đúng dữ liệu nhưng certificate không được hệ thống tin cậy/đã hết hạn."
        case .unsigned: "Tệp .p7s không chứa chữ ký CMS hợp lệ."
        case .unsupported: "Không thể xác minh định dạng CMS này."
        }
    }
}

enum CertificateSigningError: LocalizedError {
    case noIdentity
    case security(OSStatus)
    case invalidSignatureFile

    var errorDescription: String? {
        switch self {
        case .noIdentity:
            "Không tìm thấy certificate ký trong Keychain. Hãy cài certificate có private key trước."
        case let .security(status):
            (SecCopyErrorMessageString(status, nil) as String?) ?? "Lỗi Security.framework: \(status)."
        case .invalidSignatureFile:
            "Tệp chữ ký không phải CMS/PKCS#7 hợp lệ."
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

    static func verifyDetachedSignature(_ signature: Data, documentData: Data) throws -> CertificateSignatureVerification {
        var decoder: CMSDecoder?
        try check(CMSDecoderCreate(&decoder))
        guard let decoder else { throw CertificateSigningError.invalidSignatureFile }
        try signature.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { throw CertificateSigningError.invalidSignatureFile }
            try check(CMSDecoderUpdateMessage(decoder, baseAddress, signature.count))
        }
        try check(CMSDecoderFinalizeMessage(decoder))
        try check(CMSDecoderSetDetachedContent(decoder, documentData as CFData))

        var signerCount = 0
        try check(CMSDecoderGetNumSigners(decoder, &signerCount))
        guard signerCount > 0 else {
            return CertificateSignatureVerification(status: .unsigned, signerName: nil)
        }

        var certificate: SecCertificate?
        let certificateStatus = CMSDecoderCopySignerCert(decoder, 0, &certificate)
        let signerName = certificate.flatMap { SecCertificateCopySubjectSummary($0) as String? }

        var signerStatus: CMSSignerStatus = CMSSignerStatus(rawValue: 0)!
        let policy = SecPolicyCreateBasicX509()
        let status = CMSDecoderCopySignerStatus(decoder, 0, policy, true, &signerStatus, nil, nil)
        guard status == errSecSuccess else { throw CertificateSigningError.security(status) }

        let result: CertificateSignatureVerification.Status
        // CMSDecoder.h declares these stable CF_ENUM values: unsigned=0,
        // valid=1, needsDetachedContent=2, invalidSignature=3, invalidCert=4.
        switch signerStatus.rawValue {
        case 1: result = .valid
        case 3: result = .invalidSignature
        case 4: result = .invalidCertificate
        case 0: result = .unsigned
        default: result = .unsupported
        }
        _ = certificateStatus
        return CertificateSignatureVerification(status: result, signerName: signerName)
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw CertificateSigningError.security(status) }
    }
}
