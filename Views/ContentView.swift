import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: DocumentStore
    let openPDF: () -> Void
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
                    EmptyDocumentView(store: store, openPDF: openPDF)
                }
            }
            .navigationTitle(store.windowTitle)
            .toolbar { toolbar }
        }
        .overlay {
            ZStack(alignment: .top) {
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
                if let instruction = store.placementInstruction {
                    HStack {
                        Label(instruction, systemImage: "scope")
                        Button("Hủy") { store.cancelPlacement() }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
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
        .alert("Redact vĩnh viễn?", isPresented: $store.isRedactionConfirmationPresented) {
            Button("Hủy", role: .cancel) { }
            Button("Redact", role: .destructive) { store.confirmRedaction() }
        } message: {
            Text("AZpdf sẽ raster hóa trang chứa vùng chọn và thay nội dung gốc bằng vùng đen. Không thể khôi phục từ bản đã lưu; hãy dùng Undo nếu cần quay lại trong phiên này.")
        }
        .sheet(isPresented: $store.isTextAnnotationSheetPresented) {
            TextAnnotationSheet(store: store)
        }
        .sheet(isPresented: $store.isSignatureSheetPresented) {
            SignatureSheet(store: store)
        }
        .sheet(isPresented: $store.isCertificateSigningSheetPresented) {
            CertificateSignatureSheet(store: store)
        }
        .sheet(isPresented: $store.isOCRSheetPresented) {
            OCRSheet(store: store)
        }
        .sheet(isPresented: $store.isPasswordProtectSheetPresented) {
            PasswordProtectSheet(store: store)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: openPDF) { Label("Mở PDF", systemImage: "folder") }
        }
        if store.document != nil {
            ToolbarItemGroup(placement: .navigation) {
            Button { store.undo() } label: { Label("Hoàn tác", systemImage: "arrow.uturn.backward") }
                .disabled(!store.canUndo)
                .help("Hoàn tác (⌘Z)")
            Button { store.redo() } label: { Label("Làm lại", systemImage: "arrow.uturn.forward") }
                .disabled(!store.canRedo)
            Button { store.save() } label: { Label(store.isModified ? "Lưu thay đổi" : "Lưu", systemImage: "square.and.arrow.down") }
                .disabled(store.document == nil)
                .help("Lưu (⌘S)")
            Button { store.saveAs() } label: { Label("Lưu thành", systemImage: "square.and.arrow.down.on.square") }
                .help("Lưu thành bản PDF mới (⇧⌘S)")
            Button { store.isExportPresented = true } label: { Label("Xuất", systemImage: "square.and.arrow.up") }
                .help("Xuất bản sao PDF")
            }
            ToolbarItemGroup(placement: .principal) {
            Button { store.addNote() } label: { Label("Thêm ghi chú", systemImage: "note.text") }.help("Thêm ghi chú")
            Button { store.beginTextAnnotation() } label: { Label("Thêm chữ", systemImage: "text.cursor") }.help("Chèn và định dạng chữ")
            Button { store.beginSignature() } label: { Label("Chữ ký", systemImage: "signature") }.help("Vẽ và chèn chữ ký")
            Button { store.beginCertificateSigning() } label: { Label("Ký certificate", systemImage: "checkmark.seal") }.help("Xuất chữ ký số .p7s")
            Button { store.beginOCRCurrentPage() } label: { Label("OCR trang", systemImage: "text.viewfinder") }.help("Nhận dạng chữ trên trang hiện tại")
            Button { store.beginOCRDocument() } label: { Label("OCR toàn bộ", systemImage: "doc.text.magnifyingglass") }.help("Nhận dạng chữ trên toàn bộ tài liệu")
            Button { store.highlightSelection() } label: { Label("Tô sáng vùng chọn", systemImage: "highlighter") }.help("Tô sáng đoạn văn bản đã chọn")
            Button { store.beginRedaction() } label: { Label("Redact vùng chọn", systemImage: "rectangle.fill") }.help("Xóa vĩnh viễn nội dung đã chọn")
            Button { store.rotateCurrentPage() } label: { Label("Xoay trang", systemImage: "rotate.right") }.help("Xoay trang hiện tại")
            Button { store.duplicateCurrentPage() } label: { Label("Nhân đôi trang", systemImage: "plus.square.on.square") }.help("Nhân đôi trang hiện tại")
            Button { store.isInsertImporterPresented = true } label: { Label("Chèn PDF", systemImage: "doc.badge.plus") }.help("Chèn trang từ PDF khác")
            Button { store.isImageImporterPresented = true } label: { Label("Chèn ảnh", systemImage: "photo.badge.plus") }.help("Chèn ảnh thành trang mới")
            Button { store.prepareCurrentPageExport() } label: { Label("Xuất trang", systemImage: "doc.badge.arrow.up") }.help("Xuất trang hiện tại")
            Button { store.beginPasswordProtectedExport() } label: { Label("Xuất bảo vệ", systemImage: "lock.doc") }.help("Xuất PDF có mật khẩu")
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
