import SwiftUI

struct PDFConformanceSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile: PDFConformanceProfile = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kiểm tra chuẩn PDF").font(.title2.weight(.semibold))
            Text("AZpdf dùng veraPDF chạy cục bộ để kiểm tra PDF/A và PDF/UA. Kết quả không phải lời khẳng định tuân thủ nếu validator không khả dụng.")
                .foregroundStyle(.secondary)
            Picker("Profile", selection: $profile) {
                ForEach(PDFConformanceProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            if store.isConformanceChecking {
                HStack { ProgressView(); Text("Đang kiểm tra trên máy…") }
            }
            if let report = store.conformanceReport {
                LabeledContent("Kết quả") { Text(report.status.displayName) }
                TextEditor(text: .constant(report.details))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 260)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            }
            HStack {
                Button("Kiểm tra") { store.checkConformance(profile) }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isConformanceChecking)
                Spacer()
                Button("Đóng") { dismiss() }
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 430)
    }
}
