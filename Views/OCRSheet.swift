import SwiftUI

struct OCRSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.ocrTotalPages > 1 ? L("OCR Entire Document") : L("OCR Current Page")).font(.title2.weight(.semibold))
            Text(L("AZpdf prefers the PDF's existing text layer; scanned pages use Vision at 3× resolution. All processing happens on your Mac — review the result before using it."))
                .foregroundStyle(.secondary)
            if store.isOCRProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L("Recognizing Vietnamese and English — \(store.ocrCompletedPages)/\(store.ocrTotalPages) pages…"))
                }
                .frame(maxWidth: .infinity, minHeight: 230)
            } else {
                if !store.ocrReviews.isEmpty {
                    GroupBox(L("Quality Check")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.ocrReviews) { review in
                                HStack(spacing: 8) {
                                    Image(systemName: review.needsReview ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .foregroundStyle(review.needsReview ? .orange : .green)
                                    Text(L("Page \(review.pageIndex + 1)"))
                                    Text(review.source.displayName).foregroundStyle(.secondary)
                                    if let confidence = review.confidencePercent {
                                        Text("\(confidence)%").monospacedDigit().foregroundStyle(.secondary)
                                    }
                                    Text(review.layoutSummary).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(review.warning ?? L("Ready for review"))
                                        .lineLimit(1)
                                        .foregroundStyle(review.needsReview ? .orange : .secondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                TextEditor(text: $store.ocrText)
                    .font(.body)
                    .frame(minHeight: 260)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                Text(L("The preview lets you review before exporting. Edits here apply to the .txt file; the searchable PDF is rebuilt locally by OCRmyPDF to keep a standard PDF structure."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Two rows: all seven buttons on one row exceed the sheet width and
            // macOS truncates the labels to "OCR tran…", "Xuất PDF…".
            VStack(spacing: 10) {
                HStack {
                    Button(L("OCR This Page")) { store.beginOCRCurrentPage() }
                        .disabled(store.isOCRProcessing)
                    Button(L("OCR Region…")) { store.beginOCRRegionSelection() }
                        .disabled(store.isOCRProcessing)
                    Button(L("OCR All")) { store.beginOCRDocument() }
                        .disabled(store.isOCRProcessing)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button(L("Copy")) { store.copyOCRText() }
                        .disabled(store.ocrText.isEmpty || store.isOCRProcessing)
                    Button(L("Export .txt")) { store.exportOCRText() }
                        .disabled(store.ocrText.isEmpty || store.isOCRProcessing)
                    Button(store.isSearchablePDFExporting ? L("Creating PDF…") : L("Export Searchable PDF…")) { store.exportSearchablePDF() }
                        .disabled(store.ocrText.isEmpty || store.isOCRProcessing || store.isSearchablePDFExporting)
                    Button(L("Close")) { dismiss() }
                }
            }
        }
        .padding(24)
        .frame(width: 620)
    }
}
