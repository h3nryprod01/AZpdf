import SwiftUI

struct PAdESSigningSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("PAdES Digital Signing"))
                .font(.title2.weight(.semibold))
            Text(L("Baseline B works offline. LT/LTA fetch a timestamp and revocation data from the TSA you specify; the certificate and password are still processed only on this Mac."))
                .foregroundStyle(.secondary)
            Picker(L("Profile"), selection: $store.padesProfile) {
                ForEach(PAdESProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            if store.padesProfile.requiresTimestamp {
                TextField("URL TSA RFC 3161", text: $store.padesTimestampURL)
                    .textContentType(.URL)
                Text(L("LT embeds OCSP/CRL into the DSS; LTA adds a DocumentTimeStamp to begin the long-term archive chain."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Certificate") {
                Button(store.padesCertificateName.isEmpty ? L("Choose PKCS#12…") : store.padesCertificateName) {
                    store.choosePAdESCertificate()
                }
            }
            SecureField(L("PKCS#12 Password"), text: $store.padesPassword)
            Text(store.padesProfile == .baselineB ? L("PAdES Baseline B · SHA-256 · the entire PDF is signed") : L("The selected TSA must be reachable while signing; AZpdf does not store the URL or password beyond this session."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(L("Cancel"), role: .cancel) {
                    store.padesPassword = ""
                    store.padesTimestampURL = ""
                    store.padesProfile = .baselineB
                    dismiss()
                }
                Spacer()
                Button(L("Save Signed PDF…")) { store.exportPAdESSignedPDF() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.padesPKCS12Data == nil || (store.padesProfile.requiresTimestamp && store.padesTimestampURL.isEmpty))
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
