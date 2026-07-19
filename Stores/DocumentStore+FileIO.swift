import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import AZpdfCore

// Opening, saving, exporting, recent documents and document metadata.
extension DocumentStore {
    @MainActor
    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func save() {
        guard let document, let fileURL else { return }
        guard document.write(to: fileURL) else { lastError = "Không thể lưu thay đổi."; return }
        isModified = false
    }

    @MainActor
    func saveAs() {
        guard let document else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard document.write(to: url) else { lastError = "Không thể lưu bản sao PDF."; return }
        fileURL = url
        isModified = false
        addToRecentDocuments(url)
    }

    func export(to url: URL) {
        guard let document else { return }
        guard document.write(to: url) else { lastError = "Không thể xuất PDF."; return }
    }

    func beginPasswordProtectedExport() {
        guard document != nil else { return }
        exportPassword = ""
        isPasswordProtectSheetPresented = true
    }

    @MainActor func savePasswordProtectedExport() {
        let password = exportPassword
        guard !password.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title)-bao-ve.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard writeProtectedCopy(to: url, password: password) else {
            lastError = "Không thể tạo PDF được bảo vệ."
            return
        }
        exportPassword = ""
        isPasswordProtectSheetPresented = false
    }

    func writeProtectedCopy(to url: URL, password: String) -> Bool {
        guard let document, !password.isEmpty else { return false }
        return document.write(to: url, withOptions: [
            .userPasswordOption: password,
            .ownerPasswordOption: password
        ])
    }

    func prepareCurrentPageExport() {
        guard let page = document?.page(at: selectedPageIndex), let copy = page.copy() as? PDFPage else { return }
        let extracted = PDFDocument()
        extracted.insert(copy, at: 0)
        currentPageExportData = extracted.dataRepresentation()
        isCurrentPageExporterPresented = currentPageExportData != nil
    }

    func openRecentDocument(_ url: URL) {
        open(url)
    }

    func removeRecentDocument(_ url: URL) {
        recentDocumentPaths.removeAll { $0 == url.path }
        persistRecentDocuments()
    }

    func beginDocumentProperties() {
        guard let document else { return }
        let attributes = document.documentAttributes ?? [:]
        documentMetadataTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String ?? ""
        documentMetadataAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String ?? ""
        documentMetadataSubject = attributes[PDFDocumentAttribute.subjectAttribute] as? String ?? ""
        documentMetadataKeywords = attributes[PDFDocumentAttribute.keywordsAttribute] as? String ?? ""
        isDocumentPropertiesSheetPresented = true
    }

    func applyDocumentProperties() {
        guard let document else { return }
        registerUndoStep()
        var attributes = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.titleAttribute] = documentMetadataTitle.nilIfBlank
        attributes[PDFDocumentAttribute.authorAttribute] = documentMetadataAuthor.nilIfBlank
        attributes[PDFDocumentAttribute.subjectAttribute] = documentMetadataSubject.nilIfBlank
        attributes[PDFDocumentAttribute.keywordsAttribute] = documentMetadataKeywords.nilIfBlank
        document.documentAttributes = attributes
        isModified = true
        documentRevision += 1
        isDocumentPropertiesSheetPresented = false
    }
}
