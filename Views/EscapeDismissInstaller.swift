import SwiftUI
import AppKit

/// Escape bị NSTextField đang focus nuốt trước khi SwiftUI `.cancelAction`
/// thấy, nên sheet có ô nhập không đóng được bằng bàn phím. Local key monitor
/// chạy trước responder chain, bắt Escape (keyCode 53) khi sheet đang hiện.
struct EscapeDismissInstaller: NSViewRepresentable {
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onEscape: onEscape) }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    final class Coordinator {
        private var monitor: Any?
        let onEscape: () -> Void
        init(onEscape: @escaping () -> Void) { self.onEscape = onEscape }

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { self?.onEscape(); return nil }
                return event
            }
        }

        func remove() {
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        }
    }
}
