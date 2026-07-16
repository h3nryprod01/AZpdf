import SwiftUI

struct WorkspaceView: View {
    @Bindable var workspace: DocumentWorkspace

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
            ContentView(store: workspace.activeStore, openPDF: workspace.showOpenPanel)
                .id(workspace.selectedTabID)
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 4) {
            ForEach(workspace.tabs) { tab in
                WorkspaceTabItem(
                    tab: tab,
                    isSelected: workspace.selectedTabID == tab.id,
                    select: { workspace.selectTab(tab.id) },
                    close: { workspace.closeTab(tab.id) }
                )
            }

            Button(action: workspace.showOpenPanel) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Mở PDF trong tab mới")
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

}

private struct WorkspaceTabItem: View {
    let tab: DocumentWorkspace.Tab
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: select) {
                Label(tab.store.title, systemImage: tab.store.isModified ? "doc.badge.gearshape" : "doc")
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.borderless)
            .help("Đóng tab")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 6))
        .contextMenu { Button("Đóng tab", action: close) }
    }
}
