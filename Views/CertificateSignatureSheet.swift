import SwiftUI

struct CertificateSignatureSheet: View {
    @Bindable var store: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ký số bằng certificate")
                .font(.title2.weight(.semibold))
            Text("AZpdf tạo chữ ký CMS/PKCS#7 tách rời (.p7s) cho đúng bản PDF hiện tại. PDF gốc không bị sửa; khi xác minh, phải giữ nguyên cả PDF và tệp .p7s.")
                .foregroundStyle(.secondary)
            Picker("Certificate", selection: $store.selectedCertificateIdentityID) {
                ForEach(store.certificateSigningIdentities) { identity in
                    Text(identity.displayName).tag(identity.id)
                }
            }
            HStack {
                Button("Xác minh .p7s…") {
                    store.isCertificateSigningSheetPresented = false
                    store.beginCertificateSignatureVerification()
                }
                Spacer()
                Button("Hủy", role: .cancel) { store.isCertificateSigningSheetPresented = false }
                Button("Xuất chữ ký .p7s") { store.exportDetachedCertificateSignature() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.selectedCertificateIdentityID.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
