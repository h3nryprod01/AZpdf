import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

// Detached CMS/PKCS#7 certificate signing and embedded PAdES signing, plus their
// verification flows.
extension DocumentStore {
    func beginCertificateSigning() {
        guard document != nil else { return }
        do {
            certificateSigningIdentities = try CertificateSigningService.availableIdentities()
            selectedCertificateIdentityID = certificateSigningIdentities.first?.id ?? ""
            isCertificateSigningSheetPresented = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func beginCertificateSignatureVerification() {
        guard document != nil else { return }
        isCertificateSignatureImporterPresented = true
    }

    func beginPAdESSigning() {
        guard document != nil else { return }
        isPAdESSigningSheetPresented = true
    }

    func choosePAdESCertificate() {
        isPAdESCertificateImporterPresented = true
    }

    func selectPAdESCertificate(at url: URL) {
        do {
            padesPKCS12Data = try Data(contentsOf: url)
            padesCertificateName = url.lastPathComponent
        } catch {
            lastError = "Không thể đọc PKCS#12: \(error.localizedDescription)"
        }
    }

    @MainActor
    func exportPAdESSignedPDF() {
        guard let documentData = document?.dataRepresentation(), let pkcs12Data = padesPKCS12Data else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title)-signed.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        defer {
            padesPassword = ""
            padesPKCS12Data = nil
            padesCertificateName = ""
            padesTimestampURL = ""
            padesProfile = .baselineB
        }
        do {
            let signed = try PAdESSigningService.sign(
                documentData: documentData,
                pkcs12Data: pkcs12Data,
                password: padesPassword,
                profile: padesProfile,
                timestampURL: padesTimestampURL.isEmpty ? nil : padesTimestampURL
            )
            try signed.write(to: url, options: .atomic)
            isPAdESSigningSheetPresented = false
            open(url)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func verifyPAdESSignatures() {
        guard let documentData = document?.dataRepresentation() else { return }
        do {
            padesVerificationMessage = try PAdESSigningService.verify(documentData: documentData).summary
        } catch {
            padesVerificationMessage = "Không thể xác minh PAdES: \(error.localizedDescription)"
        }
        isPAdESVerificationResultPresented = true
    }

    func verifyDetachedCertificateSignature(at url: URL) {
        guard let documentData = document?.dataRepresentation() else { return }
        do {
            let signature = try Data(contentsOf: url)
            certificateVerificationMessage = try CertificateSigningService
                .verifyDetachedSignature(signature, documentData: documentData)
                .summary
        } catch {
            certificateVerificationMessage = "Không thể xác minh chữ ký: \(error.localizedDescription)"
        }
        isCertificateVerificationResultPresented = true
    }

    @MainActor
    func exportDetachedCertificateSignature() {
        guard let documentData = document?.dataRepresentation(),
              let identity = certificateSigningIdentities.first(where: { $0.id == selectedCertificateIdentityID }) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "\(title).pdf.p7s"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let signature = try CertificateSigningService.detachedSignature(for: documentData, identity: identity)
            try signature.write(to: url, options: .atomic)
            isCertificateSigningSheetPresented = false
        } catch {
            lastError = "Không thể tạo chữ ký số: \(error.localizedDescription)"
        }
    }
}
