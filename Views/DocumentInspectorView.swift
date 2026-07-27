import PDFKit
import SwiftUI

struct DocumentInspectorView: View {
    @Bindable var store: DocumentStore

    private var attributes: [AnyHashable: Any] { store.document?.documentAttributes ?? [:] }

    var body: some View {
        // Annotation and page data is read straight off PDFKit objects, which
        // @Observable cannot track. Reading documentRevision registers the one
        // dependency that does change on every edit, so the inspector refreshes
        // instead of showing a stale annotation count.
        let _ = store.documentRevision
        Form {
            Section(L("Current Page")) {
                LabeledContent(L("Position")) { Text("\(store.selectedPageIndex + 1) / \(store.pageCount)") }
                if let page = store.document?.page(at: store.selectedPageIndex) {
                    let size = page.bounds(for: .mediaBox).size
                    LabeledContent(L("Dimensions")) { Text("\(Int(size.width)) × \(Int(size.height)) pt") }
                    LabeledContent(L("Rotation")) { Text("\(page.rotation)°") }
                }
                // Two rows, not one: the inspector column is 250–360 pt and
                // English labels run ~20% longer than the Vietnamese they were
                // laid out for, so a single row truncated "Duplicate" to
                // "Dupli…" and "Export Page" to "Export…". Measured on the
                // running app, not guessed.
                Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        Button(L("Rotate")) { store.rotateCurrentPage() }
                            .frame(maxWidth: .infinity)
                        Button(L("Duplicate")) { store.duplicateCurrentPage() }
                            .frame(maxWidth: .infinity)
                    }
                    GridRow {
                        Button(L("Export Page")) { store.prepareCurrentPageExport() }
                            .frame(maxWidth: .infinity)
                        Button(L("Delete"), role: .destructive) { store.deleteCurrentPage() }
                            .frame(maxWidth: .infinity)
                            .disabled(store.pageCount <= 1)
                            // "Delete" alone is ambiguous under VoiceOver: the
                            // annotation list below has its own "Delete" and
                            // the two read identically while doing very
                            // different things.
                            .accessibilityLabel(L("Delete Page"))
                    }
                }
            }

            Section(L("Document")) {
                LabeledContent(L("Status")) { Text(store.isModified ? L("Modified, unsaved") : L("Saved")) }
                inspectorRow(L("Title"), key: PDFDocumentAttribute.titleAttribute)
                inspectorRow(L("Author"), key: PDFDocumentAttribute.authorAttribute)
                inspectorRow(L("Subject"), key: PDFDocumentAttribute.subjectAttribute)
                inspectorRow(L("Creator"), key: PDFDocumentAttribute.creatorAttribute)
                LabeledContent(L("Security")) { Text(store.document?.isEncrypted == true ? L("Encrypted") : L("No")) }
                if store.document?.isLocked == true {
                    Button(L("Unlock Document")) { store.isPasswordPromptPresented = true }
                }
                Button(L("Validate PDF/A & PDF/UA…")) { store.beginConformanceCheck() }
            }

            Section(L("PDF Forms")) {
                LabeledContent(L("Form Fields")) { Text("\(store.formFieldCount)") }
                Text(store.formFieldCount == 0
                     ? L("This document has no detectable PDF form fields.")
                     : L("Click a form field in the document to enter or choose a value. Data stays on this Mac."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let page = store.document?.page(at: store.selectedPageIndex) {
                Section(L("Annotations — \(page.annotations.count)")) {
                    if page.annotations.isEmpty {
                        Text(L("No annotations on this page.")).foregroundStyle(.secondary)
                    } else {
                        ForEach(page.annotations.indices, id: \.self) { index in
                            let annotation = page.annotations[index]
                            HStack {
                                Image(systemName: annotationSymbol(for: annotation))
                                    .foregroundStyle(.secondary)
                                Text(annotation.contents?.isEmpty == false ? annotation.contents! : (annotation.type ?? L("Annotation")))
                                    .lineLimit(2)
                                Spacer()
                                Button(L("Delete"), role: .destructive) { store.deleteAnnotation(at: index) }
                                    .buttonStyle(.borderless)
                                    // Names which annotation, so a VoiceOver
                                    // user moving down the list can tell the
                                    // rows apart — every row is just "Delete"
                                    // otherwise.
                                    .accessibilityLabel(L("Delete annotation \(index + 1)"))
                            }
                        }
                    }
                }
            }

            Section(L("Support AZpdf")) {
                Link(L("Support on Ko-fi"), destination: AZpdfLinks.koFi)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .navigationTitle(L("Inspector"))
    }

    @ViewBuilder private func inspectorRow(_ label: String, key: PDFDocumentAttribute) -> some View {
        if let value = attributes[key] as? String, !value.isEmpty {
            LabeledContent(label) { Text(value).lineLimit(2).multilineTextAlignment(.trailing) }
        }
    }

    private func annotationSymbol(for annotation: PDFAnnotation) -> String {
        switch annotation.type {
        case PDFAnnotationSubtype.highlight.rawValue: "highlighter"
        case PDFAnnotationSubtype.text.rawValue: "note.text"
        case PDFAnnotationSubtype.freeText.rawValue: "text.cursor"
        case PDFAnnotationSubtype.stamp.rawValue: "photo"
        default: "pencil.and.outline"
        }
    }
}
