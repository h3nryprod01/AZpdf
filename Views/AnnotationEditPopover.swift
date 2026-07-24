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
            Text(L("Edit Text Box")).font(.headline)
            Text(L("Drag the text box on the PDF to move it."))
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $store.selectedAnnotationText)
                .frame(minHeight: 80)

            Picker(L("Font"), selection: $store.selectedAnnotationFontName) {
                ForEach(store.availableFontFamilies, id: \.self) { Text($0).tag($0) }
            }
            Stepper(L("Font Size: \(Int(store.selectedAnnotationFontSize)) pt"), value: $store.selectedAnnotationFontSize, in: 8...72, step: 1)
            HStack(spacing: 8) {
                Toggle(isOn: $store.selectedAnnotationIsBold) { Image(systemName: "bold") }
                    .help(Text(L("Bold")))
                Toggle(isOn: $store.selectedAnnotationIsItalic) { Image(systemName: "italic") }
                    .help(Text(L("Italic")))
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

            ColorPicker(L("Text Color"), selection: nsColor($store.selectedAnnotationColor))
            boxStyleControls
            Button(L("Apply Formatting")) { store.updateSelectedFreeText() }
            deleteButton
        }
    }

    /// Frame and background of the box — shared wording with the shape editor
    /// because PDF stores both with the same two keys.
    private var boxStyleControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Toggle(L("Border"), isOn: $store.selectedAnnotationHasBorder)
            if store.selectedAnnotationHasBorder {
                ColorPicker(L("Border Color"), selection: nsColor($store.selectedAnnotationBorderColor))
                Stepper(L("Border Width: \(Int(store.selectedAnnotationLineWidth)) pt"), value: $store.selectedAnnotationLineWidth, in: 1...12, step: 1)
            }
            Toggle(L("Background"), isOn: $store.selectedAnnotationHasFill)
            if store.selectedAnnotationHasFill {
                ColorPicker(L("Background Color"), selection: nsColor($store.selectedAnnotationFillColor))
            }
        }
    }

    private func shapeSection(_ kind: ShapeKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("Edit \(kind.label.lowercased())"), systemImage: kind.symbol).font(.headline)
            Text(L("Drag to move, drag a handle to resize. Hold Shift to constrain proportions."))
                .font(.caption).foregroundStyle(.secondary)
            ColorPicker(L("Stroke Color"), selection: nsColor($store.selectedAnnotationColor))
            Stepper(L("Line Width: \(Int(store.selectedAnnotationLineWidth)) pt"), value: $store.selectedAnnotationLineWidth, in: 1...12, step: 1)
            if kind.supportsFill {
                Toggle(L("Fill"), isOn: $store.selectedAnnotationHasFill)
                if store.selectedAnnotationHasFill {
                    ColorPicker(L("Background Color"), selection: nsColor($store.selectedAnnotationFillColor))
                }
            }
            Button(L("Apply")) { store.updateSelectedShape() }
            deleteButton
        }
    }

    private func nsColor(_ binding: Binding<NSColor>) -> Binding<Color> {
        Binding(get: { Color(nsColor: binding.wrappedValue) }, set: { binding.wrappedValue = NSColor($0) })
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Edit Note")).font(.headline)
            Text(L("Click the note to edit its content, drag it directly to move."))
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $store.selectedAnnotationText)
                .frame(minHeight: 72)
            Button(L("Apply Note")) { store.updateSelectedNote() }
            deleteButton
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Edit Image")).font(.headline)
            // Was "Kéo trực tiếp ảnh trên PDF để di chuyển. Đổi kích thước rồi
            // nhấn Áp dụng." — the size steppers + Apply-size button moved to
            // handle-drag resize (Step 4), so the caption is updated to match
            // the controls actually present here.
            Text(L("Drag to move, drag a corner to resize."))
                .font(.caption).foregroundStyle(.secondary)
            Button(L("Replace Image…")) { store.beginReplaceSelectedImage() }
            deleteButton
        }
    }

    private var inkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Edit Signature")).font(.headline)
            Text(L("Drag the signature directly on the PDF to move it, or press Delete to remove it. You can change the stroke color."))
                .font(.caption).foregroundStyle(.secondary)
            ColorPicker(L("Signature Color"), selection: nsColor($store.selectedAnnotationColor))
            Button(L("Apply Color")) { store.updateSelectedInk() }
            deleteButton
        }
    }

    private var deleteButton: some View {
        Button(L("Delete Annotation"), role: .destructive) { onDelete() }
    }
}
