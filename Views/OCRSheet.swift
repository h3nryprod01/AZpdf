import SwiftUI

struct OCRSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.ocrTotalPages > 1 ? "OCR toàn bộ tài liệu" : "OCR trang hiện tại").font(.title2.weight(.semibold))
            Text("AZpdf ưu tiên text layer sẵn có của PDF; trang scan dùng Vision ở 3× resolution. Mọi xử lý diễn ra trên máy — hãy kiểm tra kết quả trước khi sử dụng.")
                .foregroundStyle(.secondary)
            if store.isOCRProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Đang nhận dạng tiếng Việt và tiếng Anh — \(store.ocrCompletedPages)/\(store.ocrTotalPages) trang…")
                }
                .frame(maxWidth: .infinity, minHeight: 230)
            } else {
                if !store.ocrReviews.isEmpty {
                    GroupBox("Kiểm tra chất lượng") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.ocrReviews) { review in
                                HStack(spacing: 8) {
                                    Image(systemName: review.needsReview ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .foregroundStyle(review.needsReview ? .orange : .green)
                                    Text("Trang \(review.pageIndex + 1)")
                                    Text(review.source.displayName).foregroundStyle(.secondary)
                                    if let confidence = review.confidencePercent {
                                        Text("\(confidence)%").monospacedDigit().foregroundStyle(.secondary)
                                    }
                                    Text(review.layoutSummary).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(review.warning ?? "Sẵn sàng review")
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
                Text("Preview dùng để review trước khi xuất. Chỉnh sửa tại đây áp dụng cho file .txt; PDF có lớp chữ được OCRmyPDF tạo lại cục bộ để giữ cấu trúc PDF chuẩn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Two rows: all seven buttons on one row exceed the sheet width and
            // macOS truncates the labels to "OCR tran…", "Xuất PDF…".
            VStack(spacing: 10) {
                HStack {
                    Button("OCR trang này") { store.beginOCRCurrentPage() }
                        .disabled(store.isOCRProcessing)
                    Button("OCR vùng…") { store.beginOCRRegionSelection() }
                        .disabled(store.isOCRProcessing)
                    Button("OCR toàn bộ") { store.beginOCRDocument() }
                        .disabled(store.isOCRProcessing)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button("Sao chép") { store.copyOCRText() }
                        .disabled(store.ocrText.isEmpty || store.isOCRProcessing)
                    Button("Xuất .txt") { store.exportOCRText() }
                        .disabled(store.ocrText.isEmpty || store.isOCRProcessing)
                    Button(store.isSearchablePDFExporting ? "Đang tạo PDF…" : "Xuất PDF có lớp chữ…") { store.exportSearchablePDF() }
                        .disabled(store.ocrText.isEmpty || store.isOCRProcessing || store.isSearchablePDFExporting)
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .padding(24)
        .frame(width: 620)
    }
}
