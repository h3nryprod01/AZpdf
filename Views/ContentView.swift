import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: DocumentStore
    @State private var isInspectorPresented = false
    @State private var isDropTarget = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            Group {
                if store.document != nil {
                    PDFReaderView(store: store)
                } else {
                    EmptyDocumentView(store: store)
                }
            }
            .navigationTitle(store.windowTitle)
            .toolbar { toolbar }
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .padding(12)
                    .allowsHitTesting(false)
                    .overlay {
                        Label("Thả PDF để mở", systemImage: "doc.badge.plus")
                            .font(.title3.weight(.semibold))
                            .padding(18)
                            .background(.regularMaterial, in: Capsule())
                    }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url, url.pathExtension.lowercased() == "pdf" else { return }
                DispatchQueue.main.async { store.open(url) }
            }
            return true
        }
        .fileImporter(isPresented: $store.isImporterPresented, allowedContentTypes: [.pdf]) { result in
            if case let .success(url) = result {
                guard url.startAccessingSecurityScopedResource() else { store.open(url); return }
                defer { url.stopAccessingSecurityScopedResource() }
                store.open(url)
            }
        }
        .fileImporter(isPresented: $store.isInsertImporterPresented, allowedContentTypes: [.pdf]) { result in
            if case let .success(url) = result {
                guard url.startAccessingSecurityScopedResource() else { store.insertPages(from: url); return }
                defer { url.stopAccessingSecurityScopedResource() }
                store.insertPages(from: url)
            }
        }
        .fileImporter(isPresented: $store.isImageImporterPresented, allowedContentTypes: [.image]) { result in
            if case let .success(url) = result {
                guard url.startAccessingSecurityScopedResource() else { store.insertImage(from: url); return }
                defer { url.stopAccessingSecurityScopedResource() }
                store.insertImage(from: url)
            }
        }
        .fileExporter(isPresented: $store.isExportPresented, document: PDFExportDocument(data: store.document?.dataRepresentation()), contentType: .pdf, defaultFilename: store.title) { _ in }
        .fileExporter(
            isPresented: $store.isCurrentPageExporterPresented,
            document: PDFExportDocument(data: store.currentPageExportData),
            contentType: .pdf,
            defaultFilename: "\(store.title)-trang-\(store.selectedPageIndex + 1)"
        ) { _ in }
        .inspector(isPresented: $isInspectorPresented) {
            DocumentInspectorView(store: store)
                .inspectorColumnWidth(min: 250, ideal: 290, max: 360)
        }
        .alert("AZpdf", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("Đóng", role: .cancel) { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
        .alert("Tài liệu được bảo vệ", isPresented: $store.isPasswordPromptPresented) {
            SecureField("Mật khẩu", text: $store.password)
            Button("Mở khóa") { store.unlockDocument() }
            Button("Hủy", role: .cancel) { store.password = "" }
        } message: {
            Text("Nhập mật khẩu để mở và chỉnh sửa tài liệu này.")
        }
        .sheet(isPresented: $store.isTextAnnotationSheetPresented) {
            TextAnnotationSheet(store: store)
        }
        .sheet(isPresented: $store.isPasswordProtectSheetPresented) {
            PasswordProtectSheet(store: store)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { store.isImporterPresented = true } label: { Label("Mở PDF", systemImage: "folder") }
        }
        if store.document != nil {
            ToolbarItemGroup(placement: .navigation) {
            Button { store.undo() } label: { Label("Hoàn tác", systemImage: "arrow.uturn.backward") }
                .disabled(!store.canUndo)
            Button { store.redo() } label: { Label("Làm lại", systemImage: "arrow.uturn.forward") }
                .disabled(!store.canRedo)
            Button { store.save() } label: { Label(store.isModified ? "Lưu thay đổi" : "Lưu", systemImage: "square.and.arrow.down") }
                .disabled(store.document == nil)
            Button { store.isExportPresented = true } label: { Label("Xuất", systemImage: "square.and.arrow.up") }
            }
            ToolbarItemGroup(placement: .principal) {
            Button { store.addNote() } label: { Label("Thêm ghi chú", systemImage: "note.text") }
            Button { store.beginTextAnnotation() } label: { Label("Thêm chữ", systemImage: "text.cursor") }
            Button { store.highlightSelection() } label: { Label("Tô sáng vùng chọn", systemImage: "highlighter") }
            Button { store.rotateCurrentPage() } label: { Label("Xoay trang", systemImage: "rotate.right") }
            Button { store.duplicateCurrentPage() } label: { Label("Nhân đôi trang", systemImage: "plus.square.on.square") }
            Button { store.isInsertImporterPresented = true } label: { Label("Chèn PDF", systemImage: "doc.badge.plus") }
            Button { store.isImageImporterPresented = true } label: { Label("Chèn ảnh", systemImage: "photo.badge.plus") }
            Button { store.prepareCurrentPageExport() } label: { Label("Xuất trang", systemImage: "doc.badge.arrow.up") }
            Button { store.beginPasswordProtectedExport() } label: { Label("Xuất bảo vệ", systemImage: "lock.doc") }
            }
            ToolbarItemGroup(placement: .automatic) {
            Button { store.goToPreviousPage() } label: { Label("Trang trước", systemImage: "chevron.left") }
                .disabled(!store.canGoToPreviousPage)
            Text("\(store.pageCount == 0 ? 0 : store.selectedPageIndex + 1) / \(store.pageCount)")
                .monospacedDigit().frame(minWidth: 46)
            Button { store.goToNextPage() } label: { Label("Trang sau", systemImage: "chevron.right") }
                .disabled(!store.canGoToNextPage)
            TextField("Tìm trong PDF", text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
            if !store.searchText.isEmpty {
                Text(store.searchResultCount == 0 ? "Không có" : "\(store.searchResultIndex)/\(store.searchResultCount)")
                    .monospacedDigit().foregroundStyle(.secondary)
                Button { store.goToPreviousSearchResult() } label: { Label("Kết quả trước", systemImage: "chevron.up") }
                    .disabled(store.searchResultCount == 0)
                Button { store.goToNextSearchResult() } label: { Label("Kết quả sau", systemImage: "chevron.down") }
                    .disabled(store.searchResultCount == 0)
            }
            Button { store.zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
            Text(store.isAutoScale ? "Vừa trang" : "\(Int(store.zoomScale * 100))%")
                .monospacedDigit().frame(minWidth: 42)
            Button { store.zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
            Button { store.fitPage() } label: { Label("Vừa trang", systemImage: "arrow.up.left.and.down.right.magnifyingglass") }
            Button { isInspectorPresented.toggle() } label: { Label("Thông tin", systemImage: "sidebar.right") }
            }
        }
    }
}

struct PDFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    let data: Data
    init(data: Data?) { self.data = data ?? Data() }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
