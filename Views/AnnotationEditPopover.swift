import PDFKit
import SwiftUI

/// Caret popover content for a selected annotation — the four type-specific
/// edit sections that used to live in the Inspector, transplanted onto the
/// same store bindings/methods now that editing happens on the object.
///
/// Deliberately no move controls: nudging is on the arrow keys (see
/// `PlacementPDFView.arrowNudge`), which keeps the non-drag path for keyboard
/// and VoiceOver users without spending popover space on four buttons.
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
            if let kind = store.selectedAnnotation?.azpdfShapeKind {
                shapeSection(kind)
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

            Picker("Phông chữ", selection: $store.selectedAnnotationFontName) {
                ForEach(store.availableFontFamilies, id: \.self) { Text($0).tag($0) }
            }
            Stepper("Cỡ chữ: \(Int(store.selectedAnnotationFontSize)) pt", value: $store.selectedAnnotationFontSize, in: 8...72, step: 1)
            HStack(spacing: 8) {
                Toggle(isOn: $store.selectedAnnotationIsBold) { Image(systemName: "bold") }
                    .help("Chữ đậm")
                Toggle(isOn: $store.selectedAnnotationIsItalic) { Image(systemName: "italic") }
                    .help("Chữ nghiêng")
                Spacer()
                Picker("", selection: $store.selectedAnnotationAlignment) {
                    Image(systemName: "text.alignleft").tag(NSTextAlignment.left)
                    Image(systemName: "text.aligncenter").tag(NSTextAlignment.center)
                    Image(systemName: "text.alignright").tag(NSTextAlignment.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)
            }
            .toggleStyle(.button)

            ColorPicker("Màu chữ", selection: nsColor($store.selectedAnnotationColor))
            boxStyleControls
            Button("Áp dụng định dạng") { store.updateSelectedFreeText() }
            deleteButton
        }
    }

    /// Frame and background of the box — shared wording with the shape editor
    /// because PDF stores both with the same two keys.
    private var boxStyleControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Toggle("Khung viền", isOn: $store.selectedAnnotationHasBorder)
            if store.selectedAnnotationHasBorder {
                ColorPicker("Màu viền", selection: nsColor($store.selectedAnnotationBorderColor))
                Stepper("Độ dày: \(Int(store.selectedAnnotationLineWidth)) pt", value: $store.selectedAnnotationLineWidth, in: 1...12, step: 1)
            }
            Toggle("Nền hộp", isOn: $store.selectedAnnotationHasFill)
            if store.selectedAnnotationHasFill {
                ColorPicker("Màu nền", selection: nsColor($store.selectedAnnotationFillColor))
            }
        }
    }

    private func shapeSection(_ kind: ShapeKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Chỉnh sửa \(kind.label.lowercased())", systemImage: kind.symbol).font(.headline)
            Text("Kéo để di chuyển, kéo tay cầm để đổi kích thước. Giữ Shift để khoá tỉ lệ.")
                .font(.caption).foregroundStyle(.secondary)
            ColorPicker("Màu nét", selection: nsColor($store.selectedAnnotationColor))
            Stepper("Độ dày nét: \(Int(store.selectedAnnotationLineWidth)) pt", value: $store.selectedAnnotationLineWidth, in: 1...12, step: 1)
            if kind.supportsFill {
                Toggle("Tô nền", isOn: $store.selectedAnnotationHasFill)
                if store.selectedAnnotationHasFill {
                    ColorPicker("Màu nền", selection: nsColor($store.selectedAnnotationFillColor))
                }
            }
            Button("Áp dụng") { store.updateSelectedShape() }
            deleteButton
        }
    }

    private func nsColor(_ binding: Binding<NSColor>) -> Binding<Color> {
        Binding(get: { Color(nsColor: binding.wrappedValue) }, set: { binding.wrappedValue = NSColor($0) })
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chỉnh sửa ghi chú").font(.headline)
            Text("Nhấp ghi chú để sửa nội dung, kéo trực tiếp để di chuyển.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $store.selectedAnnotationText)
                .frame(minHeight: 72)
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
            Button("Thay ảnh…") { store.beginReplaceSelectedImage() }
            deleteButton
        }
    }

    private var inkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chỉnh sửa chữ ký").font(.headline)
            Text("Kéo trực tiếp chữ ký trên PDF để di chuyển, hoặc nhấn Delete để xóa. Có thể đổi màu nét.")
                .font(.caption).foregroundStyle(.secondary)
            ColorPicker("Màu chữ ký", selection: nsColor($store.selectedAnnotationColor))
            Button("Áp dụng màu") { store.updateSelectedInk() }
            deleteButton
        }
    }

    private var deleteButton: some View {
        Button("Xóa chú thích", role: .destructive) { onDelete() }
    }
}
