import SwiftUI

struct EmptyDocumentView: View {
    @Bindable var store: DocumentStore
    var body: some View {
        VStack(spacing: 0) {
            ContentUnavailableView {
                Label("Mở một tài liệu PDF", systemImage: "doc.text.image")
            } description: {
                Text("Đọc, chú thích, sắp xếp trang và xuất PDF — hoàn toàn trên máy của bạn.")
            } actions: {
                Button("Mở PDF…") { store.showOpenPanel() }
                    .buttonStyle(.borderedProminent)
                Text("hoặc kéo tệp PDF vào cửa sổ")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !store.recentDocumentURLs.isEmpty {
                Divider().padding(.horizontal, 80)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gần đây").font(.headline)
                    ForEach(store.recentDocumentURLs, id: \.path) { url in
                        HStack {
                            Button { store.openRecentDocument(url) } label: {
                                Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.richtext")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button("Xóa", role: .destructive) { store.removeRecentDocument(url) }
                                .buttonStyle(.borderless)
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
