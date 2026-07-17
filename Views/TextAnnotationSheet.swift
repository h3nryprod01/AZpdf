import SwiftUI

struct TextAnnotationSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thêm chữ vào PDF").font(.title3.weight(.semibold))
            Text("Sau khi xác nhận, nhấp trực tiếp vào PDF để đặt hộp chữ tại vị trí mong muốn.")
                .foregroundStyle(.secondary)
            TextEditor(text: $store.draftTextAnnotation)
                .font(.body)
                .frame(minHeight: 130)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Spacer()
                Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Thêm chữ") { store.addTextAnnotation() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.draftTextAnnotation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
