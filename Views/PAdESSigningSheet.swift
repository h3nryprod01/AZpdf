import SwiftUI

struct PAdESSigningSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ký số PAdES")
                .font(.title2.weight(.semibold))
            Text("Baseline B hoạt động offline. LT/LTA lấy timestamp và revocation data từ TSA bạn chỉ định; certificate và mật khẩu vẫn chỉ xử lý trên máy.")
                .foregroundStyle(.secondary)
            Picker("Profile", selection: $store.padesProfile) {
                ForEach(PAdESProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            if store.padesProfile.requiresTimestamp {
                TextField("URL TSA RFC 3161", text: $store.padesTimestampURL)
                    .textContentType(.URL)
                Text("LT nhúng OCSP/CRL vào DSS; LTA thêm DocumentTimeStamp để bắt đầu chuỗi lưu trữ dài hạn.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Certificate") {
                Button(store.padesCertificateName.isEmpty ? "Chọn PKCS#12…" : store.padesCertificateName) {
                    store.choosePAdESCertificate()
                }
            }
            SecureField("Mật khẩu PKCS#12", text: $store.padesPassword)
            Text(store.padesProfile == .baselineB ? "PAdES Baseline B · SHA-256 · toàn bộ PDF được ký" : "Cần kết nối TSA đã chọn trong lúc ký; AZpdf không lưu URL hay mật khẩu ngoài phiên này.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Hủy", role: .cancel) {
                    store.padesPassword = ""
                    store.padesTimestampURL = ""
                    store.padesProfile = .baselineB
                    dismiss()
                }
                Spacer()
                Button("Lưu PDF đã ký…") { store.exportPAdESSignedPDF() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.padesPKCS12Data == nil || (store.padesProfile.requiresTimestamp && store.padesTimestampURL.isEmpty))
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
