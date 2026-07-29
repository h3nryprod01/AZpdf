import SwiftUI


@main
struct AZpdfApp: App {
    @State private var workspace = DocumentWorkspace()
    @Environment(\.openWindow) private var openWindow
    // `L(_:)` is a plain function, so switching language in Settings changes
    // what it returns but nothing tells SwiftUI to ask again. Observing the
    // choice here re-evaluates the Scene body (rebuilding the menu bar
    // commands), and keying the window root rebuilds its view tree — together
    // that is what makes the switch apply without a relaunch.
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.system.rawValue


    var body: some Scene {
        WindowGroup("AZpdf") {
            WorkspaceView(workspace: workspace)
                .frame(minWidth: 980, minHeight: 640)
                .id(appLanguage)
                // Files opened from Finder ("Open With", double-click) arrive
                // here; without this the request was dropped and macOS just
                // spawned a duplicate window.
                .onOpenURL { url in
                    guard url.isFileURL else { return }
                    workspace.openInNewTab(url)
                }
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button(L("Undo")) { workspace.activeStore.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!workspace.activeStore.canUndo)
                Button(L("Redo")) { workspace.activeStore.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!workspace.activeStore.canRedo)
            }
            CommandGroup(replacing: .newItem) {
                Button(L("Open PDF…")) { workspace.showOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button(L("Save")) { workspace.activeStore.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil || !workspace.activeStore.isModified)
                Button(L("Save As…")) { workspace.activeStore.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(workspace.activeStore.document == nil)
                Button(L("Close Tab")) { workspace.closeTab(workspace.selectedTabID) }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(replacing: .printItem) {
                Button(L("Print…")) { workspace.activeStore.printDocument() }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil)
            }
            CommandGroup(replacing: .appInfo) {
                Button(L("About AZpdf")) { openWindow(id: "about") }
            }
            // Search, zoom and the inspector used to exist only as toolbar
            // items. When the toolbar overflowed they were dropped with no
            // menu or shortcut fallback, making them unreachable at every
            // window size. These commands are that fallback.
            CommandMenu(L("View")) {
                Button(L("Find in PDF…")) { workspace.activeStore.isFindBarPresented = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil)
                Button(L("Next Result")) { workspace.activeStore.goToNextSearchResult() }
                    .keyboardShortcut("g", modifiers: .command)
                    .disabled(workspace.activeStore.searchResultCount == 0)
                Button(L("Previous Result")) { workspace.activeStore.goToPreviousSearchResult() }
                    .keyboardShortcut("g", modifiers: [.command, .option])
                    .disabled(workspace.activeStore.searchResultCount == 0)
                Divider()
                Button(L("Zoom In")) { workspace.activeStore.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil)
                Button(L("Zoom Out")) { workspace.activeStore.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil)
                Button(L("Fit Page")) { workspace.activeStore.fitPage() }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil)
                Divider()
                Button(L("Show/Hide Inspector")) { workspace.activeStore.isInspectorPresented.toggle() }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil)
            }
            CommandMenu(L("Go")) {
                Button(L("Previous Page")) { workspace.activeStore.goToPreviousPage() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!workspace.activeStore.canGoToPreviousPage)
                Button(L("Next Page")) { workspace.activeStore.goToNextPage() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!workspace.activeStore.canGoToNextPage)
            }
            CommandMenu("PDF") {
                Button(L("Add Note")) { workspace.activeStore.addNote() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button(L("Add Text…")) { workspace.activeStore.beginTextAnnotation() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button(L("Insert Signature…")) { workspace.activeStore.beginSignature() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button(L("Sign with Certificate…")) { workspace.activeStore.beginCertificateSigning() }
                Button(L("Verify .p7s Signature…")) { workspace.activeStore.beginCertificateSignatureVerification() }
                Button(L("Sign PDF with PAdES…")) { workspace.activeStore.beginPAdESSigning() }
                Button(L("Verify PAdES Signature")) { workspace.activeStore.verifyPAdESSignatures() }
                Button(L("Validate PDF/A & PDF/UA…")) { workspace.activeStore.beginConformanceCheck() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button(L("Document Properties…")) { workspace.activeStore.beginDocumentProperties() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button(L("OCR Current Page…")) { workspace.activeStore.beginOCRCurrentPage() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button(L("OCR Region…")) { workspace.activeStore.beginOCRRegionSelection() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button(L("OCR Entire Document…")) { workspace.activeStore.beginOCRDocument() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                Button(L("Highlight Selection")) { workspace.activeStore.highlightSelection() }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Button(L("Redact Selection")) { workspace.activeStore.beginRedaction() }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Divider()
                Button(L("Rotate Page Right")) { workspace.activeStore.rotateCurrentPage() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button(L("Duplicate Current Page")) { workspace.activeStore.duplicateCurrentPage() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button(L("Insert Pages from PDF…")) { workspace.activeStore.beginInsertPages() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button(L("Insert Image…")) { workspace.activeStore.beginImageInsertion() }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                Button(L("Export Current Page…")) { workspace.activeStore.prepareCurrentPageExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button(L("Export Page as Image…")) { workspace.activeStore.beginImageExport() }
                Button(L("Export Protected Copy…")) { workspace.activeStore.beginPasswordProtectedExport() }
                Button(L("Delete Current Page")) { workspace.activeStore.deleteCurrentPage() }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button(L("AZpdf Help")) { openWindow(id: "help") }
                    .keyboardShortcut("/", modifiers: [.command, .shift])
                Link(L("AZpdf Source Code"), destination: AZpdfLinks.repository)
            }
        }

        Settings {
            SettingsView()
        }

        Window(L("About AZpdf"), id: "about") {
            AboutView()
        }
        .defaultSize(width: 400, height: 330)
        .windowResizability(.contentSize)

        Window(L("AZpdf Help"), id: "help") {
            HelpView()
        }
        .defaultSize(width: 620, height: 500)
    }
}