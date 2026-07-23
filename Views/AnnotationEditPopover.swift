import PDFKit
import SwiftUI

/// Caret popover content for a selected annotation — the four type-specific
/// edit sections that used to live in the Inspector, transplanted onto the
/// same store bindings/methods now that editing happens on the object. The
/// move-arrow controls move here too (from `DocumentInspectorView`) so
/// keyboard/VoiceOver move keeps a UI trigger once dragging on the object
/// replaces the Inspector's editing sections.
struct AnnotationEditPopover: View {
    @Bindable var store: DocumentStore
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let annotation = store.selectedAnnotation, annotation.isAZpdfFreeText {
                freeTextSection
            }
            if let annotation = store.selectedAnnotation, annotation.isAZpdfNote {
                noteSection
            }
            if let annotation = store.selectedAnnotation, annotation.isAZpdfImage {
                imageSection
            }
            if let annotation = store.selectedAnnotation, annotation.isAZpdfInk {
                inkSection
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var freeTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chỉnh sửa hộp chữ").font(.headline)
            Text("Kéo trực tiếp hộp chữ trên PDF để di chuyển.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $store.selectedAnnotationText)
                .frame(minHeight: 80)
            Stepper("Cỡ chữ: \(Int(store.selectedAnnotationFontSize)) pt", value: $store.selectedAnnotationFontSize, in: 8...72, step: 1)
            ColorPicker("Màu chữ", selection: Binding(
                get: { Color(nsColor: store.selectedAnnotationColor) },
                set: { store.selectedAnnotationColor = NSColor($0) }
            ))
            positionControls
            Button("Áp dụng định dạng") { store.updateSelectedFreeText() }
            deleteButton
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chỉnh sửa ghi chú").font(.headline)
            Text("Nhấp ghi chú để sửa nội dung, kéo trực tiếp để di chuyển.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $store.selectedAnnotationText)
                .frame(minHeight: 72)
            positionControls
            Button("Áp dụng ghi chú") { store.updateSelectedNote() }
            deleteButton
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chỉnh sửa ảnh").font(.headline)
            // Was "Kéo trực tiếp ảnh trên PDF để di chuyển. Đổi kích thước rồi
            // nhấn Áp dụng." — the size steppers + Apply-size button moved to
            // handle-drag resize (Step 4), so the caption is updated to match
            // the controls actually present here.
            Text("Kéo để di chuyển, kéo góc để đổi kích thước.")
                .font(.caption).foregroundStyle(.secondary)
            positionControls
            Button("Thay ảnh…") { store.beginReplaceSelectedImage() }
            deleteButton
        }
    }

    private var inkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chỉnh sửa chữ ký").font(.headline)
            Text("Kéo trực tiếp chữ ký trên PDF để di chuyển, hoặc nhấn Delete để xóa. Có thể đổi màu nét.")
                .font(.caption).foregroundStyle(.secondary)
            ColorPicker("Màu chữ ký", selection: Binding(
                get: { Color(nsColor: store.selectedAnnotationColor) },
                set: { store.selectedAnnotationColor = NSColor($0) }
            ))
            positionControls
            Button("Áp dụng màu") { store.updateSelectedInk() }
            deleteButton
        }
    }

    private var deleteButton: some View {
        Button("Xóa chú thích", role: .destructive) { onDelete() }
    }

    /// Keyboard/VoiceOver-accessible alternative to dragging — relocated
    /// verbatim from `DocumentInspectorView.annotationPositionControls` so
    /// removing the Inspector sections doesn't drop the only non-drag way to
    /// move a selected annotation.
    private var positionControls: some View {
        HStack(spacing: 6) {
            Text("Di chuyển 8 pt")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button { store.moveSelectedAnnotation(horizontal: 0, vertical: 8) } label: {
                Label("Di chuyển lên", systemImage: "arrow.up")
            }
            .help("Di chuyển chú thích lên 8 pt")
            Button { store.moveSelectedAnnotation(horizontal: -8, vertical: 0) } label: {
                Label("Di chuyển sang trái", systemImage: "arrow.left")
            }
            .help("Di chuyển chú thích sang trái 8 pt")
            Button { store.moveSelectedAnnotation(horizontal: 8, vertical: 0) } label: {
                Label("Di chuyển sang phải", systemImage: "arrow.right")
            }
            .help("Di chuyển chú thích sang phải 8 pt")
            Button { store.moveSelectedAnnotation(horizontal: 0, vertical: -8) } label: {
                Label("Di chuyển xuống", systemImage: "arrow.down")
            }
            .help("Di chuyển chú thích xuống 8 pt")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Điều khiển vị trí chú thích")
    }
}
