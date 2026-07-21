import SwiftUI

struct DocumentPropertiesSheet: View {
    @Bindable var store: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thuộc tính tài liệu")
                .font(.title2.weight(.semibold))
            Text("Metadata giúp người đọc, công cụ tìm kiếm và kiểm tra PDF/A/PDF/UA nhận diện tài liệu chính xác hơn.")
                .foregroundStyle(.secondary)
            Form {
                TextField("Tiêu đề", text: $store.documentMetadataTitle)
                TextField("Tác giả", text: $store.documentMetadataAuthor)
                TextField("Chủ đề", text: $store.documentMetadataSubject)
                TextField("Từ khóa", text: $store.documentMetadataKeywords)
            }
            HStack {
                Spacer()
                Button("Hủy", role: .cancel) { store.isDocumentPropertiesSheetPresented = false }
                Button("Áp dụng") { store.applyDocumentProperties() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(EscapeDismissInstaller { store.isDocumentPropertiesSheetPresented = false })
    }
}
