import AppKit
import PDFKit
import XCTest
@testable import AZpdf

@MainActor
final class DocumentStoreTests: XCTestCase {
    func testDuplicateUndoAndRedoRestorePageCount() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)

        store.duplicateCurrentPage()
        XCTAssertEqual(store.pageCount, 2)
        XCTAssertTrue(store.canUndo)

        store.undo()
        XCTAssertEqual(store.pageCount, 1)
        XCTAssertTrue(store.canRedo)

        store.redo()
        XCTAssertEqual(store.pageCount, 2)
    }

    func testDeleteUndoRestoresRemovedPage() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 2)
        store.selectedPageIndex = 1

        store.deleteCurrentPage()
        XCTAssertEqual(store.pageCount, 1)
        XCTAssertEqual(store.selectedPageIndex, 0)

        store.undo()
        XCTAssertEqual(store.pageCount, 2)
        XCTAssertEqual(store.selectedPageIndex, 1)
    }

    func testMovePagesChangesOrderAndCanUndo() {
        let store = DocumentStore()
        let document = makeDocument(pageCount: 3)
        store.document = document
        store.movePages(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(store.pageCount, 3)
        XCTAssertEqual(store.document?.page(at: 0)?.bounds(for: .mediaBox).width, 101)
        XCTAssertTrue(store.isModified)

        store.undo()
        XCTAssertEqual(store.pageCount, 3)
        XCTAssertEqual(store.document?.page(at: 0)?.bounds(for: .mediaBox).width, 100)
    }

    func testInsertPagesCanBeUndone() throws {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let source = makeDocument(pageCount: 2)
        let url = try temporaryPDFURL(for: source)
        defer { try? FileManager.default.removeItem(at: url) }

        store.insertPages(from: url)
        XCTAssertEqual(store.pageCount, 3)
        XCTAssertEqual(store.selectedPageIndex, 1)

        store.undo()
        XCTAssertEqual(store.pageCount, 1)
    }

    func testCurrentPageExportContainsOnePage() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 2)
        store.selectedPageIndex = 1

        store.prepareCurrentPageExport()

        XCTAssertTrue(store.isCurrentPageExporterPresented)
        XCTAssertEqual(PDFDocument(data: store.currentPageExportData ?? Data())?.pageCount, 1)
    }

    func testPageNavigationStopsAtDocumentBounds() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 2)

        XCTAssertFalse(store.canGoToPreviousPage)
        store.goToNextPage()
        XCTAssertEqual(store.selectedPageIndex, 1)
        XCTAssertFalse(store.canGoToNextPage)
        store.goToNextPage()
        XCTAssertEqual(store.selectedPageIndex, 1)
        store.goToPreviousPage()
        XCTAssertEqual(store.selectedPageIndex, 0)
    }

    func testAddingTextQueuesAReaderAction() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        store.draftTextAnnotation = "Xin chào AZpdf"

        store.addTextAnnotation()

        XCTAssertEqual(store.readerAction, .freeText("Xin chào AZpdf"))
        XCTAssertEqual(store.readerActionID, 1)
        XCTAssertFalse(store.isTextAnnotationSheetPresented)
        XCTAssertEqual(store.placementInstruction, "Nhấp vào PDF để đặt hộp chữ.")
        XCTAssertFalse(store.isModified)
    }

    func testAddingSignatureQueuesReaderAction() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        store.draftSignatureStrokes = [SignatureStroke(points: [CGPoint(x: 4, y: 5), CGPoint(x: 12, y: 18)])]

        store.addSignature()

        XCTAssertEqual(store.readerAction, .signature([SignatureStroke(points: [CGPoint(x: 4, y: 5), CGPoint(x: 12, y: 18)])]))
        XCTAssertEqual(store.readerActionID, 1)
        XCTAssertFalse(store.isSignatureSheetPresented)
        XCTAssertEqual(store.placementInstruction, "Nhấp vào PDF để đặt chữ ký.")
        XCTAssertFalse(store.isModified)
    }

    func testCancelPlacementDoesNotCreateAnUndoStep() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        store.draftTextAnnotation = "Bản nháp"
        store.addTextAnnotation()

        store.cancelPlacement()

        XCTAssertEqual(store.readerAction, .none)
        XCTAssertNil(store.placementInstruction)
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.isModified)
    }

    func testPermanentRedactionReplacesOriginalPageContent() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let secret = PDFAnnotation(
            bounds: CGRect(x: 10, y: 10, width: 60, height: 24),
            forType: .freeText,
            withProperties: nil
        )
        secret.contents = "MẬT"
        store.document?.page(at: 0)?.addAnnotation(secret)

        let didRedact = store.permanentlyRedact([(pageIndex: 0, bounds: CGRect(x: 8, y: 8, width: 70, height: 30))])

        XCTAssertTrue(didRedact)
        XCTAssertEqual(store.document?.page(at: 0)?.annotations.count, 0)
        XCTAssertFalse(store.document?.dataRepresentation()?.contains(Data("MẬT".utf8)) ?? true)
    }

    func testFormFieldCountRecognizesWidgetAnnotations() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let field = PDFAnnotation(
            bounds: CGRect(x: 20, y: 20, width: 100, height: 30),
            forType: .widget,
            withProperties: nil
        )
        field.widgetFieldType = .text
        store.document?.page(at: 0)?.addAnnotation(field)

        XCTAssertEqual(store.formFieldCount, 1)
    }

    func testDocumentTracksUnsavedChanges() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        XCTAssertFalse(store.isModified)

        store.duplicateCurrentPage()
        XCTAssertTrue(store.isModified)
        XCTAssertEqual(store.windowTitle, "Chưa mở tài liệu — Đã chỉnh sửa")
    }

    func testDeleteAnnotationCanBeUndone() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let annotation = PDFAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 24), forType: .text, withProperties: nil)
        annotation.contents = "Ghi chú"
        store.document?.page(at: 0)?.addAnnotation(annotation)

        store.deleteAnnotation(at: 0)
        XCTAssertEqual(store.document?.page(at: 0)?.annotations.count, 0)

        store.undo()
        XCTAssertTrue(store.document?.page(at: 0)?.annotations.contains { $0.contents == "Ghi chú" } == true)
    }

    func testZoomCanSwitchBetweenFitAndManualModes() {
        let store = DocumentStore()
        XCTAssertTrue(store.isAutoScale)

        store.zoomIn()
        XCTAssertFalse(store.isAutoScale)
        XCTAssertEqual(store.zoomScale, 1.1, accuracy: 0.001)

        store.fitPage()
        XCTAssertTrue(store.isAutoScale)
    }

    func testSearchNavigationOnlyRunsWhenResultsExist() {
        let store = DocumentStore()
        store.goToNextSearchResult()
        XCTAssertEqual(store.searchNavigationID, 0)

        store.searchResultCount = 2
        store.goToPreviousSearchResult()
        XCTAssertEqual(store.searchDirection, -1)
        XCTAssertEqual(store.searchNavigationID, 1)
    }

    func testInsertImageArmsOverlayPlacement() throws {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 80,
            pixelsHigh: 80,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: .alphaFirst,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let url = FileManager.default.temporaryDirectory.appending(path: "azpdf-\(UUID().uuidString).png")
        try representation.representation(using: .png, properties: [:])!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        store.insertImage(from: url)
        XCTAssertEqual(store.pageCount, 1)
        if case .image = store.readerAction {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected image placement action")
        }
    }

    func testOCRTextNormalizationRemovesNonBreakingSpaces() {
        XCTAssertEqual(OCRService.normalized("\n  AZpdf\u{00A0}OCR\r\n"), "AZpdf OCR")
    }

    func testDetachedSignatureVerificationSummaryIsExplicit() {
        let verification = CertificateSignatureVerification(status: .invalidSignature, signerName: "AZpdf Test")
        XCTAssertTrue(verification.summary.contains("không khớp"))
        XCTAssertTrue(verification.summary.contains("AZpdf Test"))
    }

    func testDetachedSignatureVerificationOpensImporterForOpenPDF() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)

        store.beginCertificateSignatureVerification()

        XCTAssertTrue(store.isCertificateSignatureImporterPresented)
    }

    func testProtectedCopyRequiresPasswordToUnlock() throws {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let url = FileManager.default.temporaryDirectory.appending(path: "azpdf-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(store.writeProtectedCopy(to: url, password: "mat-khau"))
        let protectedDocument = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertTrue(protectedDocument.isLocked)
        XCTAssertTrue(protectedDocument.unlock(withPassword: "mat-khau"))
    }

    private func makeDocument(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 100 + index,
                pixelsHigh: 140,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: .alphaFirst,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!
            let image = NSImage(size: representation.size)
            image.addRepresentation(representation)
            document.insert(PDFPage(image: image)!, at: index)
        }
        return document
    }

    private func temporaryPDFURL(for document: PDFDocument) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "azpdf-\(UUID().uuidString).pdf")
        XCTAssertTrue(document.write(to: url))
        return url
    }
}
