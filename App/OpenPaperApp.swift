import SwiftUI

@main
struct AZpdfApp: App {
    @State private var documentStore = DocumentStore()

    var body: some Scene {
        WindowGroup("AZpdf") {
            ContentView(store: documentStore)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Hoàn tác") { documentStore.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!documentStore.canUndo)
                Button("Làm lại") { documentStore.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!documentStore.canRedo)
            }
            CommandGroup(replacing: .newItem) {
                Button("Mở PDF…") { documentStore.isImporterPresented = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Điều hướng") {
                Button("Trang trước") { documentStore.goToPreviousPage() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!documentStore.canGoToPreviousPage)
                Button("Trang sau") { documentStore.goToNextPage() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!documentStore.canGoToNextPage)
            }
            CommandMenu("PDF") {
                Button("Thêm ghi chú") { documentStore.addNote() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Thêm chữ…") { documentStore.beginTextAnnotation() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Tô sáng vùng chọn") { documentStore.highlightSelection() }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button("Xoay trang sang phải") { documentStore.rotateCurrentPage() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Nhân đôi trang hiện tại") { documentStore.duplicateCurrentPage() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Chèn trang từ PDF…") { documentStore.isInsertImporterPresented = true }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Chèn ảnh…") { documentStore.isImageImporterPresented = true }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                Button("Xuất trang hiện tại…") { documentStore.prepareCurrentPageExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Xuất bản được bảo vệ…") { documentStore.beginPasswordProtectedExport() }
                Button("Xóa trang hiện tại") { documentStore.deleteCurrentPage() }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
