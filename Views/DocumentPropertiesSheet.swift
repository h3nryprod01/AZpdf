import SwiftUI

struct DocumentPropertiesSheet: View {
    @Bindable var store: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Document Properties"))
                .font(.title2.weight(.semibold))
            Text(L("Metadata helps readers, search tools, and PDF/A/PDF/UA validators identify your document more accurately."))
                .foregroundStyle(.secondary)
            Form {
                TextField(L("Title"), text: $store.documentMetadataTitle)
                TextField(L("Author"), text: $store.documentMetadataAuthor)
                TextField(L("Subject"), text: $store.documentMetadataSubject)
                TextField(L("Keywords"), text: $store.documentMetadataKeywords)
            }
            HStack {
                Spacer()
                Button(L("Cancel"), role: .cancel) { store.isDocumentPropertiesSheetPresented = false }
                Button(L("Apply")) { store.applyDocumentProperties() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(EscapeDismissInstaller { store.isDocumentPropertiesSheetPresented = false })
    }
}
