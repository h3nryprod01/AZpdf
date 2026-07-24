import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: DocumentStore
    let openPDF: () -> Void
    @State private var isDropTarget = false
    @State private var isShapePickerPresented = false
    @FocusState private var isFindFieldFocused: Bool

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            VStack(spacing: 0) {
                if store.isFindBarPresented { findBar }
                if store.isEditBarPresented, store.document != nil {
                    editBar
                    Divider()
                }
                Group {
                    if store.document != nil {
                        PDFReaderView(store: store)
                    } else {
                        EmptyDocumentView(store: store, openPDF: openPDF)
                    }
                }
            }
            .navigationTitle(store.windowTitle)
            .toolbar { toolbar }
            .onChange(of: store.isFindBarPresented) { _, shown in
                isFindFieldFocused = shown
            }
        }
        .overlay {
            ZStack(alignment: .top) {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                        .padding(12)
                        .allowsHitTesting(false)
                        .overlay {
                            Label(L("Drop PDF to open"), systemImage: "doc.badge.plus")
                                .font(.title3.weight(.semibold))
                                .padding(18)
                                .background(.regularMaterial, in: Capsule())
                        }
                }
                if let instruction = store.placementInstruction {
                    HStack {
                        Label(instruction, systemImage: "scope")
                        Button(L("Cancel")) { store.cancelPlacement() }
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
        // Only ONE fileExporter remains here on purpose: SwiftUI keeps just the
        // last presentation modifier of each kind per view, so the pickers that
        // used to be stacked above this one never opened. They now use native
        // panels from the store instead.
        .fileExporter(
            isPresented: $store.isCurrentPageExporterPresented,
            document: PDFExportDocument(data: store.currentPageExportData),
            contentType: .pdf,
            // Not localized: this is a filename built from the document's own
            // title, not UI copy. Running it through L(_:) looked up a key that
            // never exists and only worked by falling through to the identity
            // value — and would have produced a wrong filename the day someone
            // "translated" it.
            defaultFilename: "\(store.title)-page-\(store.selectedPageIndex + 1)"
        ) { _ in }
        .inspector(isPresented: $store.isInspectorPresented) {
            DocumentInspectorView(store: store)
                .inspectorColumnWidth(min: 250, ideal: 290, max: 360)
        }
        .alert("AZpdf", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button(L("Close"), role: .cancel) { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
        .alert(L("Protected Document"), isPresented: $store.isPasswordPromptPresented) {
            SecureField(L("Password"), text: $store.password)
            Button(L("Unlock")) { store.unlockDocument() }
            Button(L("Cancel"), role: .cancel) { store.password = "" }
        } message: {
            Text(L("Enter the password to open and edit this document."))
        }
        .alert(L("Redact permanently?"), isPresented: $store.isRedactionConfirmationPresented) {
            Button(L("Cancel"), role: .cancel) { }
            Button(L("Redact"), role: .destructive) { store.confirmRedaction() }
        } message: {
            Text(L("AZpdf will rasterize the page containing the selection and replace the original content with a black box. This can't be recovered once saved — use Undo if you need to go back during this session."))
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
        .sheet(isPresented: $store.isPAdESSigningSheetPresented) {
            PAdESSigningSheet(store: store)
        }
        .alert(L("Verify Digital Signature"), isPresented: $store.isCertificateVerificationResultPresented) {
            Button(L("OK"), role: .cancel) { }
        } message: {
            Text(store.certificateVerificationMessage)
        }
        .alert(L("Verify PAdES"), isPresented: $store.isPAdESVerificationResultPresented) {
            Button(L("OK"), role: .cancel) { }
        } message: {
            Text(store.padesVerificationMessage)
        }
        .sheet(isPresented: $store.isOCRSheetPresented) {
            OCRSheet(store: store)
        }
        .sheet(isPresented: $store.isConformanceSheetPresented) {
            PDFConformanceSheet(store: store)
        }
        .sheet(isPresented: $store.isDocumentPropertiesSheetPresented) {
            DocumentPropertiesSheet(store: store)
        }
        .sheet(isPresented: $store.isPasswordProtectSheetPresented) {
            PasswordProtectSheet(store: store)
        }
    }

    // Lives below the toolbar rather than inside it: a toolbar TextField is
    // dropped silently when the toolbar overflows, which made search
    // unreachable at every window size.
    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(L("Find in PDF"), text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .focused($isFindFieldFocused)
                .onSubmit { store.goToNextSearchResult() }
            if !store.searchText.isEmpty {
                Text(store.searchResultCount == 0 ? L("No results") : "\(store.searchResultIndex)/\(store.searchResultCount)")
                    .monospacedDigit().foregroundStyle(.secondary)
                Button { store.goToPreviousSearchResult() } label: { Image(systemName: "chevron.up") }
                    .disabled(store.searchResultCount == 0)
                    .help(Text(L("Previous result (⌥⌘G)")))
                    .accessibilityLabel(L("Previous result"))
                Button { store.goToNextSearchResult() } label: { Image(systemName: "chevron.down") }
                    .disabled(store.searchResultCount == 0)
                    .help(Text(L("Next result (⌘G)")))
                    .accessibilityLabel(L("Next result"))
            }
            Spacer()
            Button(L("Done")) {
                store.isFindBarPresented = false
                store.searchText = ""
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        // Focus has to be set after the field is in the hierarchy AND after the
        // AppKit PDFView has settled, otherwise it keeps first responder and
        // the field stays empty while the user types.
        .task {
            try? await Task.sleep(for: .milliseconds(120))
            isFindFieldFocused = true
        }
    }

    // Preview-style edit bar: revealed by the toolbar "Chỉnh sửa" toggle. It
    // holds the annotation / page / OCR / signing tools that used to crowd the
    // toolbar. Labels are visible here (unlike the cramped toolbar), and moving
    // these out is also what keeps search and zoom from being pushed into an
    // overflow menu that never opened.
    private var editBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Every icon is an outline SF Symbol at one size. A single filled
            // glyph (Redact was `rectangle.fill`, PAdES `checkmark.seal.fill`)
            // reads as heavier than its neighbours and breaks the row.
            HStack(spacing: 0) {
                editTool(L("Note"), "note.text") { store.addNote() }
                editTool(L("Text"), "character.textbox") { store.beginTextAnnotation() }
                editTool(L("Signature"), "signature") { store.beginSignature() }
                editTool(L("Highlight"), "highlighter") { store.highlightSelection() }
                editTool(L("Image"), "photo") { store.beginImageInsertion() }
                shapeMenu
                editTool(L("Redact"), "eye.slash") { store.beginRedaction() }
                editDivider
                editTool(L("Rotate"), "rotate.right") { store.rotateCurrentPage() }
                editTool(L("Duplicate"), "plus.square.on.square") { store.duplicateCurrentPage() }
                editTool(L("Insert PDF"), "doc.badge.plus") { store.beginInsertPages() }
                editTool(L("Export Page"), "doc.badge.arrow.up") { store.prepareCurrentPageExport() }
                editTool(L("Export Protected"), "lock.doc") { store.beginPasswordProtectedExport() }
                editDivider
                editTool(L("OCR Page"), "text.viewfinder") { store.beginOCRCurrentPage() }
                editTool(L("OCR Region"), "viewfinder") { store.beginOCRRegionSelection() }
                editTool(L("OCR All"), "doc.text.magnifyingglass") { store.beginOCRDocument() }
                editDivider
                // Three distinct outline glyphs: seal signs, shield signs with a
                // long-term profile, circle reports a verification result.
                editTool(L("Sign .p7s"), "checkmark.seal") { store.beginCertificateSigning() }
                editTool(L("Sign PAdES"), "checkmark.shield") { store.beginPAdESSigning() }
                editTool(L("Verify"), "checkmark.circle") { store.verifyPAdESSignatures() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    private var editDivider: some View {
        Divider().frame(height: 30).padding(.horizontal, 4)
    }

    /// One slot in the bar for six shapes — the same grouping Preview uses for
    /// its shape submenu.
    ///
    /// A popover rather than a `Menu`: macOS `Menu` always lays an Image-plus-Text
    /// label out horizontally as a `Label`, whatever the stack or the menu
    /// style, so "Hình" sat beside its icon while every neighbour stacked
    /// icon-over-label. A plain Button takes `editToolLabel` verbatim, so this
    /// slot is pixel-identical to its neighbours.
    private var shapeMenu: some View {
        Button { isShapePickerPresented.toggle() } label: {
            editToolLabel(L("Shape"), "square.on.circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .help(Text(L("Insert shape: rectangle, oval, line, arrow, star, triangle")))
        .popover(isPresented: $isShapePickerPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(ShapeKind.allCases) { kind in
                    Button {
                        isShapePickerPresented = false
                        store.beginShape(kind)
                    } label: {
                        Label(kind.label, systemImage: kind.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                }
            }
            .padding(10)
            .frame(width: 170)
        }
    }

    private func editTool(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { editToolLabel(title, icon) }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
    }

    /// Shared by the buttons and the shape menu so both stack identically. The
    /// fixed icon box is what puts every label on one baseline: SF Symbols have
    /// different intrinsic heights, so without it a wide glyph pushes its label
    /// down relative to its neighbours.
    private func editToolLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .frame(width: 22, height: 19)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(minWidth: Self.editToolWidth)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private static let editToolWidth: CGFloat = 58

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: openPDF) { Label(L("Open PDF"), systemImage: "folder") }
        }
        if store.document != nil {
            ToolbarItemGroup(placement: .navigation) {
            Button { store.undo() } label: { Label(L("Undo"), systemImage: "arrow.uturn.backward") }
                .disabled(!store.canUndo)
                .help(Text(L("Undo (⌘Z)")))
            Button { store.redo() } label: { Label(L("Redo"), systemImage: "arrow.uturn.forward") }
                .disabled(!store.canRedo)
            Button { store.save() } label: { Label(store.isModified ? L("Save Changes") : L("Save"), systemImage: "square.and.arrow.down") }
                .disabled(store.document == nil)
                .help(Text(L("Save (⌘S)")))
            Button { store.saveAs() } label: { Label(L("Save As"), systemImage: "square.and.arrow.down.on.square") }
                .help(Text(L("Save as a new PDF (⇧⌘S)")))
            Button { store.beginExportCopy() } label: { Label(L("Export"), systemImage: "square.and.arrow.up") }
                .help(Text(L("Export a PDF copy")))
            }
            ToolbarItem(placement: .principal) {
                Button { store.isEditBarPresented.toggle() } label: {
                    Label(L("Edit"), systemImage: "pencil.tip.crop.circle")
                }
                .help(Text(L("Show/hide editing tools")))
                .tint(store.isEditBarPresented ? .accentColor : nil)
            }
            ToolbarItemGroup(placement: .automatic) {
            Button { store.goToPreviousPage() } label: { Label(L("Previous Page"), systemImage: "chevron.left") }
                .disabled(!store.canGoToPreviousPage)
            Text("\(store.pageCount == 0 ? 0 : store.selectedPageIndex + 1) / \(store.pageCount)")
                .monospacedDigit().frame(minWidth: 46)
                .accessibilityLabel(L("Page \(store.pageCount == 0 ? 0 : store.selectedPageIndex + 1) of \(store.pageCount)"))
            Button { store.goToNextPage() } label: { Label(L("Next Page"), systemImage: "chevron.right") }
                .disabled(!store.canGoToNextPage)
            Button { store.isFindBarPresented.toggle() } label: { Label(L("Find"), systemImage: "magnifyingglass") }
                .help(Text(L("Find in PDF (⌘F)")))
            Button { store.zoomOut() } label: { Label(L("Zoom Out"), systemImage: "minus.magnifyingglass") }
            Text(store.isAutoScale ? L("Fit Page") : "\(Int(store.zoomScale * 100))%")
                .monospacedDigit().frame(minWidth: 42)
                .accessibilityLabel(store.isAutoScale ? L("Fit Page") : L("Zoom \(Int(store.zoomScale * 100)) percent"))
            Button { store.zoomIn() } label: { Label(L("Zoom In"), systemImage: "plus.magnifyingglass") }
            Button { store.fitPage() } label: { Label(L("Fit Page"), systemImage: "arrow.up.left.and.down.right.magnifyingglass") }
            Button { store.beginDocumentProperties() } label: { Label(L("Properties"), systemImage: "doc.text") }
                .help(Text(L("Edit title, author, and PDF metadata")))
            Button { store.isInspectorPresented.toggle() } label: { Label(L("Inspector"), systemImage: "sidebar.right") }
                .help(Text(L("Show/Hide Inspector (⌘I)")))
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
