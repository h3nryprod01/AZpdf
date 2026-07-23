import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

// Selecting and editing annotations, and placing notes, text, highlights,
// signatures and images onto the page.
extension DocumentStore {
    func selectAnnotation(_ annotation: PDFAnnotation?, pageIndex: Int?) {
        selectedAnnotation = annotation
        selectedAnnotationPageIndex = pageIndex
        selectedAnnotationText = annotation?.contents ?? ""
        selectedAnnotationFontSize = Double(annotation?.font?.pointSize ?? 14)
        selectedAnnotationColor = annotation?.fontColor ?? annotation?.color ?? .labelColor
        selectedAnnotationWidth = Double(annotation?.bounds.width ?? 0)
        selectedAnnotationHeight = Double(annotation?.bounds.height ?? 0)
        annotationSelectionID += 1
    }

    func beginAnnotationMove() {
        registerUndoStep()
    }

    func finishAnnotationMove() {
        guard selectedAnnotation != nil else { return }
        isModified = true
    }

    /// Mirrors `beginAnnotationMove`: snapshots for undo at drag-start, before
    /// the view starts mutating `bounds` live.
    func beginAnnotationResize() {
        registerUndoStep()
    }

    /// Commits a resize drag. No `registerUndoStep` here — `beginAnnotationResize`
    /// already snapshotted the pre-drag state at drag-start.
    func resizeSelectedAnnotation(to newBounds: CGRect) {
        guard let annotation = selectedAnnotation else { return }
        annotation.bounds = CGRect(
            x: newBounds.minX,
            y: newBounds.minY,
            width: max(24, newBounds.width),
            height: max(24, newBounds.height)
        )
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func updateSelectedFreeText() {
        guard let annotation = selectedAnnotation,
              annotation.isAZpdfFreeText else { return }
        registerUndoStep()
        annotation.contents = selectedAnnotationText
        annotation.font = .systemFont(ofSize: selectedAnnotationFontSize)
        annotation.fontColor = selectedAnnotationColor
        annotation.color = .clear
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func updateSelectedNote() {
        guard let annotation = selectedAnnotation else { return }
        registerUndoStep()
        annotation.contents = selectedAnnotationText
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func beginImageInsertion() {
        isReplacingSelectedImage = false
        showImageOpenPanel()
    }

    func beginReplaceSelectedImage() {
        guard selectedAnnotation is EditableImageAnnotation else { return }
        isReplacingSelectedImage = true
        showImageOpenPanel()
    }

    @MainActor
    private func showImageOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else {
            isReplacingSelectedImage = false
            return
        }
        importImage(from: url)
    }

    /// Provides a keyboard and VoiceOver-accessible alternative to dragging an annotation.
    func moveSelectedAnnotation(horizontal: CGFloat, vertical: CGFloat) {
        guard let annotation = selectedAnnotation,
              let document,
              let pageIndex = selectedAnnotationPageIndex,
              let page = document.page(at: pageIndex) else { return }
        registerUndoStep()
        let cropBox = page.bounds(for: .cropBox)
        let candidate = annotation.bounds.offsetBy(dx: horizontal, dy: vertical)
        annotation.bounds = CGRect(
            x: min(max(candidate.minX, cropBox.minX), cropBox.maxX - candidate.width),
            y: min(max(candidate.minY, cropBox.minY), cropBox.maxY - candidate.height),
            width: candidate.width,
            height: candidate.height
        )
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func addNote() {
        sendReaderAction(.addNote)
    }

    func beginTextAnnotation() {
        guard document != nil else { return }
        draftTextAnnotation = ""
        isTextAnnotationSheetPresented = true
    }

    func addTextAnnotation() {
        let text = draftTextAnnotation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isTextAnnotationSheetPresented = false
        draftTextAnnotation = ""
        placementInstruction = "Nhấp vào PDF để đặt hộp chữ."
        sendReaderAction(.freeText(text), recordsUndo: false)
    }

    func highlightSelection() {
        sendReaderAction(.highlightSelection)
    }

    func beginSignature() {
        guard document != nil else { return }
        draftSignatureStrokes = []
        isSignatureSheetPresented = true
    }

    func addSignature() {
        let strokes = draftSignatureStrokes.filter { $0.points.count > 1 }
        guard !strokes.isEmpty else {
            lastError = "Hãy vẽ chữ ký trước khi chèn."
            return
        }
        isSignatureSheetPresented = false
        draftSignatureStrokes = []
        placementInstruction = "Nhấp vào PDF để đặt chữ ký."
        sendReaderAction(.signature(strokes), recordsUndo: false)
    }

    func cancelPlacement() {
        placementInstruction = nil
        readerAction = .none
        readerActionID += 1
    }

    func prepareAnnotationPlacement() {
        registerUndoStep()
    }

    func finishAnnotationPlacement(_ operation: DocumentOperation) {
        placementInstruction = nil
        record(operation)
        isModified = true
    }

    func deleteAnnotation(at index: Int) {
        guard let page = document?.page(at: selectedPageIndex), page.annotations.indices.contains(index) else { return }
        registerUndoStep()
        page.removeAnnotation(page.annotations[index])
        documentRevision += 1
        isModified = true
    }

    /// Deletes whatever annotation is currently selected — the path the Delete
    /// key and the right-click menu use, so a selected signature or image can be
    /// removed in place instead of only from the inspector's list.
    func deleteSelectedAnnotation() {
        guard let annotation = selectedAnnotation,
              let pageIndex = selectedAnnotationPageIndex,
              let page = document?.page(at: pageIndex) else { return }
        registerUndoStep()
        page.removeAnnotation(annotation)
        selectAnnotation(nil, pageIndex: nil)
        documentRevision += 1
        isModified = true
    }

    /// Recolors the selected ink signature. Ink strokes cannot be re-drawn after
    /// the fact, but colour is the one property worth editing.
    func updateSelectedInk() {
        guard let annotation = selectedAnnotation, annotation.isAZpdfInk else { return }
        registerUndoStep()
        annotation.color = selectedAnnotationColor
        annotation.modificationDate = Date()
        isModified = true
        documentRevision += 1
    }

    func importImage(from url: URL) {
        if isReplacingSelectedImage {
            isReplacingSelectedImage = false
            replaceSelectedImage(from: url)
        } else {
            insertImage(from: url)
        }
    }

    func insertImage(from url: URL) {
        guard document != nil, NSImage(contentsOf: url) != nil else {
            lastError = "Không thể đọc ảnh để chèn."
            return
        }
        do {
            let imageURL = try cachedImageURL(from: url)
            placementInstruction = "Nhấp vào PDF để đặt ảnh. Sau đó kéo ảnh để di chuyển hoặc chọn ảnh để đổi kích thước."
            sendReaderAction(.image(imageURL), recordsUndo: false)
        } catch {
            lastError = "Không thể chuẩn bị ảnh để chèn: \(error.localizedDescription)"
        }
    }

    func insertImageOverlay(from imageURL: URL, pageIndex: Int, bounds: CGRect) {
        guard let page = document?.page(at: pageIndex), let image = NSImage(contentsOf: imageURL) else {
            lastError = "Không thể đọc ảnh để chèn."
            return
        }
        registerUndoStep()
        let annotation = EditableImageAnnotation(image: image, bounds: bounds)
        page.addAnnotation(annotation)
        selectAnnotation(annotation, pageIndex: pageIndex)
        documentRevision += 1
        placementInstruction = nil
        isModified = true
        record(.addAnnotation(kind: .image, page: pageIndex))
    }

    private func replaceSelectedImage(from url: URL) {
        guard let annotation = selectedAnnotation as? EditableImageAnnotation,
              let image = NSImage(contentsOf: url) else {
            lastError = "Không thể đọc ảnh thay thế."
            return
        }
        registerUndoStep()
        annotation.replaceImage(image)
        documentRevision += 1
        isModified = true
    }

    private func cachedImageURL(from url: URL) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "AZpdf-Images", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        let destination = directory.appending(path: "\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }
}
