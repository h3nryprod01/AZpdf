import SwiftUI

@main
struct AZpdfApp: App {
    @State private var workspace = DocumentWorkspace()

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
                Button("Đóng tab") { workspace.closeTab(workspace.selectedTabID) }
                    .keyboardShortcut("w", modifiers: .command)
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
                    .keyboardShortcut("s", modifiers: [.command, .shift])
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
                Button("Chèn ảnh…") { workspace.activeStore.isImageImporterPresented = true }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                Button("Xuất trang hiện tại…") { workspace.activeStore.prepareCurrentPageExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Xuất bản được bảo vệ…") { workspace.activeStore.beginPasswordProtectedExport() }
                Button("Xóa trang hiện tại") { workspace.activeStore.deleteCurrentPage() }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
