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

    func testSelectedNoteCanBeEdited() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let note = PDFAnnotation(bounds: CGRect(x: 20, y: 20, width: 32, height: 32), forType: .text, withProperties: nil)
        note.contents = "Cũ"
        store.document?.page(at: 0)?.addAnnotation(note)
        store.selectAnnotation(note, pageIndex: 0)
        store.selectedAnnotationText = "Mới"

        store.updateSelectedNote()

        XCTAssertEqual(note.contents, "Mới")
        XCTAssertTrue(store.isModified)
    }

    func testImageInsertionUsesEditableAnnotation() throws {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let image = NSImage(size: CGSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 20, height: 20)).fill()
        image.unlockFocus()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("azpdf-editable-image.png")
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation ?? Data())
        try XCTUnwrap(bitmap?.representation(using: .png, properties: [:])).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        store.insertImageOverlay(from: url, pageIndex: 0, bounds: CGRect(x: 24, y: 24, width: 80, height: 60))

        XCTAssertTrue(store.document?.page(at: 0)?.annotations.last is EditableImageAnnotation)
        XCTAssertTrue(store.isModified)
    }

    func testOCRRegionArmsSelectionWithoutChangingDocument() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)

        store.beginOCRRegionSelection()

        XCTAssertEqual(store.readerAction, .ocrRegion)
        XCTAssertEqual(store.placementInstruction, "Kéo trên PDF để chọn vùng cần OCR.")
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

    func testSelectedAnnotationCanMoveWithAccessibleControlsAndUndo() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let annotation = PDFAnnotation(
            bounds: CGRect(x: 20, y: 20, width: 40, height: 24),
            forType: .freeText,
            withProperties: nil
        )
        store.document?.page(at: 0)?.addAnnotation(annotation)
        store.selectAnnotation(annotation, pageIndex: 0)

        store.moveSelectedAnnotation(horizontal: 8, vertical: -8)

        XCTAssertEqual(annotation.bounds.origin, CGPoint(x: 28, y: 12))
        XCTAssertTrue(store.isModified)
        XCTAssertTrue(store.canUndo)

        store.undo()
        XCTAssertEqual(store.document?.page(at: 0)?.annotations.first?.bounds.origin, CGPoint(x: 20, y: 20))
    }

    func testOCRTextNormalizationRemovesNonBreakingSpaces() {
        XCTAssertEqual(OCRService.normalized("\n  AZpdf\u{00A0}OCR\r\n"), "AZpdf OCR")
    }

    func testOCRMyPDFServiceCreatesReplacementPDF() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "azpdf-ocrmypdf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "ocrmypdf")
        try "#!/bin/sh\ncp \"${6}\" \"${7}\"\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let output = try OCRMyPDFService.createSearchablePDF(
            documentData: Data("%PDF searchable".utf8),
            executable: executable
        )

        XCTAssertEqual(output, Data("%PDF searchable".utf8))
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

    func testPAdESSigningServiceUsesPassfileAndReturnsEmbeddedPDF() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "azpdf-pades-sign-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "pyhanko")
        try "#!/bin/sh\ncp \"${9}\" \"${10}\"\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let signed = try PAdESSigningService.sign(
            documentData: Data("%PDF-test".utf8),
            pkcs12Data: Data("test-p12".utf8),
            password: "secret",
            executable: executable
        )

        XCTAssertEqual(signed, Data("%PDF-test".utf8))
    }

    func testPAdESLTRequiresTimestampURL() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "azpdf-pades-lt-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "pyhanko")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        XCTAssertThrowsError(try PAdESSigningService.sign(
            documentData: Data("%PDF-test".utf8),
            pkcs12Data: Data("test-p12".utf8),
            password: "secret",
            profile: .baselineLT,
            executable: executable
        )) { error in
            XCTAssertEqual(error.localizedDescription, PAdESSigningError.timestampURLRequired.localizedDescription)
        }
    }

    func testPAdESVerifierSeparatesIntegrityAndCertificateTrust() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "azpdf-pades-verify-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "pyhanko")
        try """
        #!/bin/sh
        echo "Certificate subject: \\\"AZpdf Test\\\""
        echo "The signer's certificate is untrusted."
        echo "The signature is cryptographically sound."
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let verification = try PAdESSigningService.verify(documentData: Data("%PDF-test".utf8), executable: executable)

        XCTAssertEqual(verification.integrity, .valid)
        XCTAssertEqual(verification.certificateTrust, .untrusted)
        XCTAssertEqual(verification.signerName, "AZpdf Test")
    }

    func testConformanceReportParsesComplianceResult() throws {
        let data = try XCTUnwrap("{\"report\":{\"isCompliant\":true}}".data(using: .utf8))
        let report = PDFConformanceService.parse(data, profile: .pdfA4)
        XCTAssertEqual(report.status, .compliant)
        XCTAssertEqual(report.profile, .pdfA4)
    }

    func testConformanceReportParsesActualVeraPDFResultShape() throws {
        let json = """
        {"report":{"jobs":[{"validationResult":[{"profileName":"PDF/A-1b validation profile","compliant":false}]}]}}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let report = PDFConformanceService.parse(data, profile: .automatic)

        XCTAssertEqual(report.status, .nonCompliant)
    }

    func testConformanceReportExtractsActionableAccessibilityFinding() throws {
        let json = """
        {"report":{"isCompliant":false,"testAssertions":[{"ruleId":"UA-7.18","message":"Document structure tags are missing"}]}}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let report = PDFConformanceService.parse(data, profile: .pdfUA2)

        XCTAssertEqual(report.findings.count, 1)
        XCTAssertEqual(report.findings[0].rule, "UA-7.18")
        XCTAssertTrue(report.findings[0].guidance.contains("semantic tag"))
    }

    func testOCRReviewFlagsLowConfidenceVisionResult() {
        let review = OCRPageReview(
            pageIndex: 1,
            source: .vision,
            confidence: 0.73,
            lineCount: 12,
            warning: "Độ tin cậy thấp; kiểm tra lại thứ tự đọc và ký tự trước khi xuất."
        )

        XCTAssertEqual(review.confidencePercent, 73)
        XCTAssertTrue(review.needsReview)
    }

    func testConformanceServiceRunsLocalValidatorAndReadsReport() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "azpdf-verapdf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "verapdf")
        try "#!/bin/sh\necho '{\"report\":{\"isCompliant\":false}}'\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let report = try PDFConformanceService.validate(Data("%PDF".utf8), profile: .pdfUA2, executable: executable)

        XCTAssertEqual(report.status, .nonCompliant)
        XCTAssertEqual(report.profile, .pdfUA2)
    }

    func testConformanceServiceReadsNonCompliantReportDespiteValidatorExitStatus() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "azpdf-verapdf-exit-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "verapdf")
        try "#!/bin/sh\necho '{\"report\":{\"isCompliant\":false}}'\nexit 1\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let report = try PDFConformanceService.validate(Data("%PDF".utf8), profile: .pdfA4, executable: executable)

        XCTAssertEqual(report.status, .nonCompliant)
    }

    func testConformanceServiceWithInstalledVeraPDF() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AZPDF_RUN_EXTERNAL_INTEGRATION"] == "1",
              let path = environment["AZPDF_EXTERNAL_PDF"] else {
            throw XCTSkip("Set AZPDF_RUN_EXTERNAL_INTEGRATION=1 and AZPDF_EXTERNAL_PDF=/path/to/test.pdf to run veraPDF locally.")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))

        let report = try PDFConformanceService.validate(data, profile: .pdfA4)

        XCTAssertNotEqual(report.status, .unknown)
        XCTAssertFalse(report.details.isEmpty)
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
