import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class DocumentWorkspace {
    struct Tab: Identifiable {
        let id: UUID
        let store: DocumentStore

        @MainActor init(id: UUID = UUID(), store: DocumentStore = DocumentStore()) {
            self.id = id
            self.store = store
        }
    }

    private(set) var tabs: [Tab]
    var selectedTabID: UUID

    init() {
        let initialTab = Tab()
        tabs = [initialTab]
        selectedTabID = initialTab.id
    }

    var activeStore: DocumentStore {
        tabs.first(where: { $0.id == selectedTabID })?.store ?? tabs[0].store
    }

    func createEmptyTab() {
        let tab = Tab()
        tabs.append(tab)
        selectedTabID = tab.id
    }

    func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
    }

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if tabs[index].store.isModified {
            tabs[index].store.lastError = "Hãy lưu thay đổi trước khi đóng tab."
            return
        }
        if tabs.count == 1 {
            tabs[0] = Tab()
            selectedTabID = tabs[0].id
            return
        }
        tabs.remove(at: index)
        selectedTabID = tabs[max(0, index - 1)].id
    }

    func openInNewTab(_ url: URL) {
        let store = DocumentStore()
        store.open(url)
        guard store.document != nil else { return }
        let tab = Tab(store: store)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    @MainActor
    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openInNewTab(url)
    }
}
