import SwiftUI

struct PDFConformanceSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile: PDFConformanceProfile = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kiểm tra chuẩn PDF").font(.title2.weight(.semibold))
            Text("AZpdf dùng veraPDF chạy cục bộ để kiểm tra PDF/A và PDF/UA. Profile tự động đọc claim XMP; PDF không có claim sẽ được kiểm tra theo fallback PDF/A-1b. Kết quả không phải lời khẳng định tuân thủ nếu validator không khả dụng.")
                .foregroundStyle(.secondary)
            Picker("Profile", selection: $profile) {
                ForEach(PDFConformanceProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            if store.isConformanceChecking {
                HStack { ProgressView(); Text("Đang kiểm tra trên máy…") }
            }
            if let error = store.conformanceError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if let report = store.conformanceReport {
                LabeledContent("Kết quả") { Text(report.status.displayName) }
                Text(report.summary).foregroundStyle(.secondary)
                if !report.findings.isEmpty {
                    GroupBox("Hạng mục cần xử lý") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(report.findings) { finding in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Label(finding.severity.displayName, systemImage: finding.severity == .error ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                            .foregroundStyle(finding.severity == .error ? .orange : .secondary)
                                        Text(finding.message).font(.callout)
                                        Text("\(finding.rule) · \(finding.guidance)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                }
                DisclosureGroup("Dữ liệu thô từ veraPDF") {
                    TextEditor(text: .constant(report.details))
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 160)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                }
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
