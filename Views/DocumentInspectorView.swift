import PDFKit
import SwiftUI

struct DocumentInspectorView: View {
    @Bindable var store: DocumentStore

    private var attributes: [AnyHashable: Any] { store.document?.documentAttributes ?? [:] }

    var body: some View {
        Form {
            Section("Trang hiện tại") {
                LabeledContent("Vị trí") { Text("\(store.selectedPageIndex + 1) / \(store.pageCount)") }
                if let page = store.document?.page(at: store.selectedPageIndex) {
                    let size = page.bounds(for: .mediaBox).size
                    LabeledContent("Kích thước") { Text("\(Int(size.width)) × \(Int(size.height)) pt") }
                    LabeledContent("Góc xoay") { Text("\(page.rotation)°") }
                }
                HStack {
                    Button("Xoay") { store.rotateCurrentPage() }
                    Button("Nhân đôi") { store.duplicateCurrentPage() }
                    Button("Xuất trang") { store.prepareCurrentPageExport() }
                    Button("Xóa", role: .destructive) { store.deleteCurrentPage() }
                        .disabled(store.pageCount <= 1)
                }
            }

            Section("Tài liệu") {
                LabeledContent("Trạng thái") { Text(store.isModified ? "Đã chỉnh sửa, chưa lưu" : "Đã lưu") }
                inspectorRow("Tiêu đề", key: PDFDocumentAttribute.titleAttribute)
                inspectorRow("Tác giả", key: PDFDocumentAttribute.authorAttribute)
                inspectorRow("Chủ đề", key: PDFDocumentAttribute.subjectAttribute)
                inspectorRow("Nhà tạo", key: PDFDocumentAttribute.creatorAttribute)
                LabeledContent("Bảo mật") { Text(store.document?.isEncrypted == true ? "Đã mã hóa" : "Không") }
                if store.document?.isLocked == true {
                    Button("Mở khóa tài liệu") { store.isPasswordPromptPresented = true }
                }
                Button("Kiểm tra PDF/A & PDF/UA…") { store.beginConformanceCheck() }
            }

            Section("Biểu mẫu PDF") {
                LabeledContent("Trường tương tác") { Text("\(store.formFieldCount)") }
                Text(store.formFieldCount == 0
                     ? "Tài liệu này không có trường form PDF được phát hiện."
                     : "Nhấp trực tiếp vào trường form trong tài liệu để nhập hoặc chọn giá trị. Dữ liệu được giữ trên máy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let page = store.document?.page(at: store.selectedPageIndex) {
                Section("Chú thích — \(page.annotations.count)") {
                    if page.annotations.isEmpty {
                        Text("Không có chú thích trên trang này.").foregroundStyle(.secondary)
                    } else {
                        ForEach(page.annotations.indices, id: \.self) { index in
                            let annotation = page.annotations[index]
                            HStack {
                                Image(systemName: annotationSymbol(for: annotation))
                                    .foregroundStyle(.secondary)
                                Text(annotation.contents?.isEmpty == false ? annotation.contents! : (annotation.type ?? "Chú thích"))
                                    .lineLimit(2)
                                Spacer()
                                Button("Xóa", role: .destructive) { store.deleteAnnotation(at: index) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }

            if let annotation = store.selectedAnnotation,
               annotation.type == PDFAnnotationSubtype.freeText.rawValue {
                Section("Chỉnh sửa hộp chữ") {
                    Text("Kéo trực tiếp hộp chữ trên PDF để di chuyển.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $store.selectedAnnotationText)
                        .frame(minHeight: 80)
                    Stepper("Cỡ chữ: \(Int(store.selectedAnnotationFontSize)) pt", value: $store.selectedAnnotationFontSize, in: 8...72, step: 1)
                    ColorPicker("Màu chữ", selection: Binding(
                        get: { Color(nsColor: store.selectedAnnotationColor) },
                        set: { store.selectedAnnotationColor = NSColor($0) }
                    ))
                    Button("Áp dụng định dạng") { store.updateSelectedFreeText() }
                }
            }

            if let annotation = store.selectedAnnotation,
               annotation.type == PDFAnnotationSubtype.stamp.rawValue {
                Section("Chỉnh sửa ảnh") {
                    Text("Kéo trực tiếp ảnh trên PDF để di chuyển. Đổi kích thước rồi nhấn Áp dụng.")
                        .font(.caption).foregroundStyle(.secondary)
                    Stepper("Rộng: \(Int(store.selectedAnnotationWidth)) pt", value: $store.selectedAnnotationWidth, in: 24...1_200, step: 4)
                    Stepper("Cao: \(Int(store.selectedAnnotationHeight)) pt", value: $store.selectedAnnotationHeight, in: 24...1_200, step: 4)
                    Button("Áp dụng kích thước") { store.updateSelectedImageSize() }
                }
            }

            Section("Ủng hộ AZpdf") {
                Link("Ủng hộ qua Ko-fi", destination: AZpdfLinks.koFi)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .navigationTitle("Thông tin")
    }

    @ViewBuilder private func inspectorRow(_ label: String, key: PDFDocumentAttribute) -> some View {
        if let value = attributes[key] as? String, !value.isEmpty {
            LabeledContent(label) { Text(value).lineLimit(2).multilineTextAlignment(.trailing) }
        }
    }

    private func annotationSymbol(for annotation: PDFAnnotation) -> String {
        switch annotation.type {
        case PDFAnnotationSubtype.highlight.rawValue: "highlighter"
        case PDFAnnotationSubtype.text.rawValue: "note.text"
        case PDFAnnotationSubtype.freeText.rawValue: "text.cursor"
        case PDFAnnotationSubtype.stamp.rawValue: "photo"
        default: "pencil.and.outline"
        }
    }
}
