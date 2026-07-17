import SwiftUI

@main
struct AZpdfApp: App {
    @State private var workspace = DocumentWorkspace()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("AZpdf") {
            WorkspaceView(workspace: workspace)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Hoàn tác") { workspace.activeStore.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!workspace.activeStore.canUndo)
                Button("Làm lại") { workspace.activeStore.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!workspace.activeStore.canRedo)
            }
            CommandGroup(replacing: .newItem) {
                Button("Mở PDF…") { workspace.showOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Lưu") { workspace.activeStore.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(workspace.activeStore.document == nil || !workspace.activeStore.isModified)
                Button("Lưu thành…") { workspace.activeStore.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(workspace.activeStore.document == nil)
                Button("Đóng tab") { workspace.closeTab(workspace.selectedTabID) }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("Giới thiệu về AZpdf") { openWindow(id: "about") }
            }
            CommandMenu("Điều hướng") {
                Button("Trang trước") { workspace.activeStore.goToPreviousPage() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!workspace.activeStore.canGoToPreviousPage)
                Button("Trang sau") { workspace.activeStore.goToNextPage() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!workspace.activeStore.canGoToNextPage)
            }
            CommandMenu("PDF") {
                Button("Thêm ghi chú") { workspace.activeStore.addNote() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Thêm chữ…") { workspace.activeStore.beginTextAnnotation() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Chèn chữ ký…") { workspace.activeStore.beginSignature() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Ký bằng certificate…") { workspace.activeStore.beginCertificateSigning() }
                Button("Xác minh chữ ký .p7s…") { workspace.activeStore.beginCertificateSignatureVerification() }
                Button("Ký PAdES vào PDF…") { workspace.activeStore.beginPAdESSigning() }
                Button("Xác minh chữ ký PAdES") { workspace.activeStore.verifyPAdESSignatures() }
                Button("Kiểm tra PDF/A & PDF/UA…") { workspace.activeStore.beginConformanceCheck() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("OCR trang hiện tại…") { workspace.activeStore.beginOCRCurrentPage() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("OCR vùng…") { workspace.activeStore.beginOCRRegionSelection() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button("OCR toàn bộ tài liệu…") { workspace.activeStore.beginOCRDocument() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                Button("Tô sáng vùng chọn") { workspace.activeStore.highlightSelection() }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Redact vùng chọn") { workspace.activeStore.beginRedaction() }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Divider()
                Button("Xoay trang sang phải") { workspace.activeStore.rotateCurrentPage() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Nhân đôi trang hiện tại") { workspace.activeStore.duplicateCurrentPage() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Chèn trang từ PDF…") { workspace.activeStore.isInsertImporterPresented = true }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Chèn ảnh…") { workspace.activeStore.beginImageInsertion() }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                Button("Xuất trang hiện tại…") { workspace.activeStore.prepareCurrentPageExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Xuất bản được bảo vệ…") { workspace.activeStore.beginPasswordProtectedExport() }
                Button("Xóa trang hiện tại") { workspace.activeStore.deleteCurrentPage() }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button("Trợ giúp AZpdf") { openWindow(id: "help") }
                    .keyboardShortcut("/", modifiers: [.command, .shift])
                Link("Mã nguồn AZpdf", destination: AZpdfLinks.repository)
            }
        }

        Settings {
            SettingsView()
        }

        Window("Giới thiệu về AZpdf", id: "about") {
            AboutView()
        }
        .defaultSize(width: 400, height: 330)
        .windowResizability(.contentSize)

        Window("Trợ giúp AZpdf", id: "help") {
            HelpView()
        }
        .defaultSize(width: 620, height: 500)
    }
}
