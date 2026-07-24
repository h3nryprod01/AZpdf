import SwiftUI

struct EmptyDocumentView: View {
    @Bindable var store: DocumentStore
    let openPDF: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ContentUnavailableView {
                Label(L("Open a PDF Document"), systemImage: "doc.text.image")
            } description: {
                Text(L("Read, annotate, organize pages, and export PDFs — entirely on your Mac."))
            } actions: {
                Button(L("Open PDF…"), action: openPDF)
                    .buttonStyle(.borderedProminent)
                Text(L("or drag a PDF into the window"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !store.recentDocumentURLs.isEmpty {
                Divider().padding(.horizontal, 80)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Recents")).font(.headline)
                    ForEach(store.recentDocumentURLs, id: \.path) { url in
                        HStack {
                            Button { store.openRecentDocument(url) } label: {
                                Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.richtext")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(L("Remove"), role: .destructive) { store.removeRecentDocument(url) }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(L("Remove \(url.deletingPathExtension().lastPathComponent) from Recents"))
                        }
                    }
                }
                .frame(maxWidth: 460, alignment: .leading)
                .padding(.top, 18)
            }
        }
        .padding(.bottom, 34)
    }
}
