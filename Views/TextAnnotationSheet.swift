import SwiftUI

struct TextAnnotationSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Add Text to PDF")).font(.title3.weight(.semibold))
            Text(L("After confirming, click directly on the PDF to place the text box where you want it."))
                .foregroundStyle(.secondary)
            TextEditor(text: $store.draftTextAnnotation)
                .font(.body)
                .frame(minHeight: 130)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Spacer()
                Button(L("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Add Text")) { store.addTextAnnotation() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.draftTextAnnotation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(EscapeDismissInstaller { dismiss() })
    }
}
