import SwiftUI

struct OCRSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.ocrTotalPages > 1 ? "OCR toàn bộ tài liệu" : "OCR trang hiện tại").font(.title2.weight(.semibold))
            Text("Vision xử lý ảnh trang ở 3× resolution hoàn toàn trên máy. Hãy kiểm tra kết quả trước khi sử dụng.")
                .foregroundStyle(.secondary)
            if store.isOCRProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Đang nhận dạng tiếng Việt và tiếng Anh — \(store.ocrCompletedPages)/\(store.ocrTotalPages) trang…")
                }
                .frame(maxWidth: .infinity, minHeight: 230)
            } else {
                TextEditor(text: $store.ocrText)
                    .font(.body)
                    .frame(minHeight: 260)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            }
            HStack {
                Button("OCR trang này") { store.beginOCRCurrentPage() }
                    .disabled(store.isOCRProcessing)
                Button("OCR toàn bộ") { store.beginOCRDocument() }
                    .disabled(store.isOCRProcessing)
                Spacer()
                Button("Sao chép") { store.copyOCRText() }
                    .disabled(store.ocrText.isEmpty || store.isOCRProcessing)
                Button("Xuất .txt") { store.exportOCRText() }
                    .disabled(store.ocrText.isEmpty || store.isOCRProcessing)
                Button("Đóng") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 620)
    }
}
