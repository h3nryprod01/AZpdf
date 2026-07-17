import SwiftUI

struct PAdESSigningSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ký số PAdES")
                .font(.title2.weight(.semibold))
            Text("Chữ ký được nhúng vào PDF theo PAdES Baseline B. Certificate và mật khẩu được xử lý hoàn toàn trên máy; mật khẩu chỉ tồn tại trong lúc ký.")
                .foregroundStyle(.secondary)
            LabeledContent("Certificate") {
                Button(store.padesCertificateName.isEmpty ? "Chọn PKCS#12…" : store.padesCertificateName) {
                    store.choosePAdESCertificate()
                }
            }
            SecureField("Mật khẩu PKCS#12", text: $store.padesPassword)
            Text("PAdES Baseline B · SHA-256 · toàn bộ PDF được ký")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Hủy", role: .cancel) {
                    store.padesPassword = ""
                    dismiss()
                }
                Spacer()
                Button("Lưu PDF đã ký…") { store.exportPAdESSignedPDF() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.padesPKCS12Data == nil)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
