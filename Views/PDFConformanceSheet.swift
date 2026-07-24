import SwiftUI

struct PDFConformanceSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile: PDFConformanceProfile = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Validate PDF Conformance")).font(.title2.weight(.semibold))
            Text(L("AZpdf uses veraPDF locally to validate PDF/A and PDF/UA. The automatic profile reads the XMP claim; a PDF with no claim is checked against the PDF/A-1b fallback. The result is not a compliance assertion if the validator is unavailable."))
                .foregroundStyle(.secondary)
            Picker(L("Profile"), selection: $profile) {
                ForEach(PDFConformanceProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            if store.isConformanceChecking {
                HStack { ProgressView(); Text(L("Validating on this Mac…")) }
            }
            if let error = store.conformanceError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if let report = store.conformanceReport {
                LabeledContent(L("Result")) { Text(report.status.displayName) }
                Text(report.summary).foregroundStyle(.secondary)
                if !report.findings.isEmpty {
                    GroupBox(L("Issues to Fix")) {
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
                DisclosureGroup(L("Raw veraPDF Output")) {
                    TextEditor(text: .constant(report.details))
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 160)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                }
            }
            HStack {
                Button(L("Validate")) { store.checkConformance(profile) }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isConformanceChecking)
                Spacer()
                Button(L("Close")) { dismiss() }
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 430)
    }
}
