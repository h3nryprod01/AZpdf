import PDFKit
import SwiftUI

struct SidebarView: View {
    @Bindable var store: DocumentStore

    var body: some View {
        let _ = store.documentRevision
        List(selection: $store.selectedPageIndex) {
            if let document = store.document {
                let outlineItems = PDFOutlineItem.makeItems(from: document.outlineRoot, in: document)
                if !outlineItems.isEmpty {
                    Section("Mục lục") {
                        ForEach(outlineItems) { item in
                            OutlineRow(item: item, selectPage: { store.selectedPageIndex = $0 })
                        }
                    }
                }
                Section("Trang — \(document.pageCount)") {
                    // Array, not a literal Range: SwiftUI treats ForEach over a
                    // constant range as static content and ignores .onMove, so
                    // dragging a thumbnail only selected it instead of
                    // reordering the page.
                    ForEach(Array(0..<document.pageCount), id: \.self) { index in
                        HStack(spacing: 10) {
                            PageThumbnail(page: document.page(at: index))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trang \(index + 1)")
                                Text(document.page(at: index)?.label ?? "PDF")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(index)
                        .contextMenu {
                            Button("Nhân đôi trang") { store.selectedPageIndex = index; store.duplicateCurrentPage() }
                            Button("Xoay trang") { store.selectedPageIndex = index; store.rotateCurrentPage() }
                            Divider()
                            Button("Xóa trang", role: .destructive) { store.selectedPageIndex = index; store.deleteCurrentPage() }
                        }
                    }
                    .onMove(perform: store.movePages)
                }
            } else {
                // Without this the sidebar is a blank column on launch, which
                // reads as something failing to load rather than as "no
                // document yet".
                Text("Mở một PDF để xem mục lục và thumbnail trang.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 190, ideal: 230)
    }
}

private struct PDFOutlineItem: Identifiable {
    let id = UUID()
    let title: String
    let pageIndex: Int?
    let children: [PDFOutlineItem]

    static func makeItems(from root: PDFOutline?, in document: PDFDocument) -> [PDFOutlineItem] {
        guard let root else { return [] }
        return (0..<root.numberOfChildren).compactMap { root.child(at: $0) }.map { makeItem(from: $0, in: document) }
    }

    private static func makeItem(from outline: PDFOutline, in document: PDFDocument) -> PDFOutlineItem {
        let children = (0..<outline.numberOfChildren).compactMap { outline.child(at: $0) }.map { makeItem(from: $0, in: document) }
        let pageIndex: Int?
        if let page = outline.destination?.page {
            let index = document.index(for: page)
            pageIndex = index == NSNotFound ? nil : index
        } else {
            pageIndex = nil
        }
        return PDFOutlineItem(
            title: outline.label ?? "Không tiêu đề",
            pageIndex: pageIndex,
            children: children
        )
    }
}

private struct OutlineRow: View {
    let item: PDFOutlineItem
    let selectPage: (Int) -> Void

    var body: some View {
        Group {
            if item.children.isEmpty {
                outlineButton
            } else {
                DisclosureGroup {
                    ForEach(item.children) { child in
                        OutlineRow(item: child, selectPage: selectPage)
                    }
                } label: {
                    outlineButton
                }
            }
        }
    }

    private var outlineButton: some View {
        Button {
            if let pageIndex = item.pageIndex { selectPage(pageIndex) }
        } label: {
            Text(item.title).lineLimit(1)
        }
        .buttonStyle(.plain)
        .disabled(item.pageIndex == nil)
    }
}

private struct PageThumbnail: View {
    let page: PDFPage?
    var body: some View {
        Group {
            if let image = page?.thumbnail(of: CGSize(width: 34, height: 44), for: .mediaBox) {
                Image(nsImage: image).resizable().scaledToFit()
            } else { Image(systemName: "doc") }
        }
        .frame(width: 34, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.quaternary))
    }
}
