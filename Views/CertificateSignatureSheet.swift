import SwiftUI

struct CertificateSignatureSheet: View {
    @Bindable var store: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Sign with a Certificate"))
                .font(.title2.weight(.semibold))
            Text(L("AZpdf creates a detached CMS/PKCS#7 signature (.p7s) for the exact current PDF. The original PDF is not modified; when verifying, keep both the PDF and the .p7s file intact."))
                .foregroundStyle(.secondary)
            Picker(L("Certificate"), selection: $store.selectedCertificateIdentityID) {
                ForEach(store.certificateSigningIdentities) { identity in
                    Text(identity.displayName).tag(identity.id)
                }
            }
            HStack {
                Button(L("Verify .p7s…")) {
                    store.isCertificateSigningSheetPresented = false
                    store.beginCertificateSignatureVerification()
                }
                Spacer()
                Button(L("Cancel"), role: .cancel) { store.isCertificateSigningSheetPresented = false }
                Button(L("Export .p7s Signature")) { store.exportDetachedCertificateSignature() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.selectedCertificateIdentityID.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
