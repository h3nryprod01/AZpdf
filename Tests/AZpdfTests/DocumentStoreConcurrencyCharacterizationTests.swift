import AppKit
import PDFKit
import XCTest
@testable import AZpdf

// Characterization tests that pin the CURRENT behavior of the DispatchQueue-based
// concurrency sites in Stores/ (DocumentStore+OCR.swift, DocumentStore+Conformance.swift)
// before the PHA 3 refactor to async/await. They are the safety net for that refactor.
//
// Why this file exists: a targeted mutation run measured a 0 % kill rate in
// DocumentStore+OCR.swift — the suite was green against every wrong behavior there.
// So these tests assert structural state (flags, counts, review sources) that is
// observable and deterministic, never wall-clock durations or locale-dependent text.
//
// Determinism notes:
// - makeDocument() builds blank image-only pages → OCRService.textLayer returns nil
//   and recognizeDetailed throws noTextFound on them, so the OCR completion takes the
//   .failure branch regardless of what Vision actually recognizes.
// - checkConformance spawns verapdf; whether the binary is present or not, the
//   completion fires and sets exactly one of conformanceReport / conformanceError.
@MainActor
final class DocumentStoreConcurrencyCharacterizationTests: XCTestCase {

    // MARK: - makeOCRReview warning decision (pure; pins +OCR L122/124/126)

    func testOCRReviewWarnsOnMultiColumnLayoutFlag() {
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.99,
            lineCount: 12, layoutSummary: "multi", needsLayoutReview: true)
        XCTAssertNotNil(review.warning)
    }

    func testOCRReviewWarnsOnLowConfidenceVision() {
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.5,
            lineCount: 8, layoutSummary: "single", needsLayoutReview: false)
        XCTAssertNotNil(review.warning)
    }

    func testOCRReviewWarnsOnZeroRecognizedLines() {
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.9,
            lineCount: 0, layoutSummary: "single", needsLayoutReview: false)
        XCTAssertNotNil(review.warning)
    }

    func testOCRReviewHasNoWarningForCleanVisionPage() {
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.9,
            lineCount: 8, layoutSummary: "single", needsLayoutReview: false)
        XCTAssertNil(review.warning)
    }

    func testOCRReviewTextLayerNeverTriggersConfidenceWarning() {
        // textLayer is not .vision → the confidence branch must not fire even at 0.1.
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .textLayer, confidence: 0.1,
            lineCount: 8, layoutSummary: "Text layer PDF", needsLayoutReview: false)
        XCTAssertNil(review.warning)
    }

    // MARK: - makeOCRReview minConfidence (B3.5.3 — avg hides outlier, min doesn't)

    func testOCRReviewWarnsOnLowMinConfidence() {
        // avg confidence is high (0.96) so the existing avg<0.85 branch must NOT fire;
        // only the new minConfidence<0.5 branch can. Written RED before that branch exists.
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.96,
            minConfidence: 0.30,
            lineCount: 8, layoutSummary: "single", needsLayoutReview: false)
        XCTAssertNotNil(review.warning)
    }

    func testOCRReviewNoWarningWhenMinConfidenceIsHigh() {
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.96,
            minConfidence: 0.90,
            lineCount: 8, layoutSummary: "single", needsLayoutReview: false)
        XCTAssertNil(review.warning)
    }

    // MARK: - makeOCRReview page-level formula/figure signal (B3.5.5 — ≥2 low-letter-ratio lines)

    func testOCRReviewWarnsOnMultipleLowLetterRatioLines() {
        // confidence/minConfidence are high so only the letter-ratio branch can fire.
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.99, minConfidence: 0.90,
            lowLetterRatioLineCount: 2,
            lineCount: 8, layoutSummary: "single", needsLayoutReview: false)
        XCTAssertNotNil(review.warning)
    }

    func testOCRReviewNoFormulaWarningBelowTwoLowLetterRatioLines() {
        let review = DocumentStore.makeOCRReview(
            pageIndex: 0, source: .vision, confidence: 0.99, minConfidence: 0.90,
            lowLetterRatioLineCount: 1,
            lineCount: 8, layoutSummary: "single", needsLayoutReview: false)
        XCTAssertNil(review.warning)
    }

    // MARK: - beginOCRRegion synchronous setup + guards (pins +OCR L28-36)

    func testBeginOCRRegionSetsProcessingStateSynchronously() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let pageBounds = store.document!.page(at: 0)!.bounds(for: .cropBox)

        store.beginOCRRegion(pageIndex: 0, bounds: pageBounds)

        // Asserted before the async completion can run: the synchronous setup.
        XCTAssertEqual(store.ocrPageIndex, 0)
        XCTAssertEqual(store.ocrTotalPages, 1)
        XCTAssertEqual(store.ocrCompletedPages, 0)
        XCTAssertTrue(store.isOCRSheetPresented)
        XCTAssertTrue(store.isOCRProcessing)
        XCTAssertEqual(store.ocrText, "")
        XCTAssertTrue(store.ocrReviews.isEmpty)
        XCTAssertNil(store.placementInstruction)
    }

    func testBeginOCRRegionIsNoOpWhenAlreadyProcessing() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        store.isOCRProcessing = true

        store.beginOCRRegion(pageIndex: 0, bounds: CGRect(x: 0, y: 0, width: 10, height: 10))

        XCTAssertFalse(store.isOCRSheetPresented)
    }

    func testBeginOCRRegionIsNoOpWithoutDocument() {
        let store = DocumentStore()

        store.beginOCRRegion(pageIndex: 0, bounds: CGRect(x: 0, y: 0, width: 10, height: 10))

        XCTAssertFalse(store.isOCRSheetPresented)
        XCTAssertFalse(store.isOCRProcessing)
    }

    // MARK: - beginOCRRegion async completion (pins +OCR L43/44/50/51)

    func testBeginOCRRegionCompletesWithUnavailableReviewForBlankPage() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let pageBounds = store.document!.page(at: 0)!.bounds(for: .cropBox)

        store.beginOCRRegion(pageIndex: 0, bounds: pageBounds)

        waitFor { store.isOCRProcessing == false }

        XCTAssertFalse(store.isOCRProcessing)
        XCTAssertEqual(store.ocrCompletedPages, 1)
        XCTAssertEqual(store.ocrReviews.count, 1)
        XCTAssertEqual(store.ocrReviews.first?.source, .unavailable)
        XCTAssertFalse(store.ocrText.isEmpty)
        XCTAssertTrue(store.ocrText.contains("Page 1"))
    }

    // MARK: - beginOCR (document/page) async completion (pins +OCR L81/102/109)

    func testBeginOCRDocumentCompletesWithOneReviewPerPage() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)

        store.beginOCRDocument()

        waitFor { store.isOCRProcessing == false }

        XCTAssertFalse(store.isOCRProcessing)
        XCTAssertEqual(store.ocrCompletedPages, 1)
        XCTAssertEqual(store.ocrReviews.count, 1)
        XCTAssertEqual(store.ocrReviews.first?.source, .unavailable)
        XCTAssertTrue(store.ocrText.contains("Page 1"))
    }

    // MARK: - Conformance synchronous setup + guards (pins +Conformance L7/10/15)

    func testBeginConformanceCheckPresentsSheetWhenDocumentExists() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        store.conformanceError = "stale"

        store.beginConformanceCheck()

        XCTAssertTrue(store.isConformanceSheetPresented)
        XCTAssertNil(store.conformanceError)
        XCTAssertNil(store.conformanceReport)
    }

    func testBeginConformanceCheckIsNoOpWithoutDocument() {
        let store = DocumentStore()

        store.beginConformanceCheck()

        XCTAssertFalse(store.isConformanceSheetPresented)
    }

    func testCheckConformanceSetsCheckingFlagSynchronously() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let profile = PDFConformanceProfile.allCases.first!

        store.checkConformance(profile)

        XCTAssertTrue(store.isConformanceChecking)
        XCTAssertNil(store.conformanceError)
    }

    func testCheckConformanceIsNoOpWithoutDocument() {
        let store = DocumentStore()
        let profile = PDFConformanceProfile.allCases.first!

        store.checkConformance(profile)

        XCTAssertFalse(store.isConformanceChecking)
    }

    // MARK: - Conformance async completion (pins +Conformance L21/23/24)

    func testCheckConformanceCompletesAndClearsCheckingFlag() {
        let store = DocumentStore()
        store.document = makeDocument(pageCount: 1)
        let profile = PDFConformanceProfile.allCases.first!

        store.checkConformance(profile)

        waitFor { store.isConformanceChecking == false }

        XCTAssertFalse(store.isConformanceChecking)
        let reportSet = store.conformanceReport != nil
        let errorSet = store.conformanceError != nil
        XCTAssertTrue(reportSet || errorSet)
        XCTAssertFalse(reportSet && errorSet)
    }

    // MARK: - Helpers

    /// Spins the main run loop so DispatchQueue.main.async completions can fire,
    /// until `condition` holds or a generous timeout is reached. Bounds a wait — it
    /// does not assert any duration value.
    private func waitFor(timeout: TimeInterval = 20, condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out after \(timeout)s waiting for an async completion")
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
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
}

// MARK: - exportSearchablePDF (phần B3.2 bị NSSavePanel chặn)

extension DocumentStoreConcurrencyCharacterizationTests {

    /// Ghim hành vi `performSearchablePDFExport` TRƯỚC khi đổi concurrency.
    ///
    /// Phần này trước đây nằm sau `panel.runModal()` nên không viết test được, và mutation
    /// trên vùng đó sống sót 100 %. Test dùng `waitFor` (quay run loop) nên chạy được cả
    /// trên bản `DispatchQueue` lẫn bản `async` — nghĩa là nó ghim HÀNH VI, không mô tả
    /// cách cài đặt.
    ///
    /// Đường đo được là nhánh THẤT BẠI: máy chạy test không có runtime OCRmyPDF nên
    /// `createSearchablePDF` ném `runtimeUnavailable`. Bất biến phải giữ: hạ cờ bận, đẩy lỗi
    /// lên `lastError`, KHÔNG đóng sheet OCR, và không ghi file ra đích.
    func testSearchablePDFExportFailureClearsBusyFlagAndSurfacesError() {
        let store = DocumentStore()
        store.isOCRSheetPresented = true
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "azpdf-searchable-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: destination) }

        store.performSearchablePDFExport(documentData: Data("%PDF-1.4 fixture".utf8), to: destination)
        waitFor { !store.isSearchablePDFExporting }

        XCTAssertNotNil(store.lastError, "thất bại phải nổi lên lastError")
        XCTAssertTrue(store.isOCRSheetPresented, "thất bại thì KHÔNG được đóng sheet OCR")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path),
                       "thất bại thì không được ghi file ra đích")
    }

    /// Cờ bận phải bật ĐỒNG BỘ ngay khi gọi. Nếu nó chỉ bật bên trong tác vụ nền thì UI có
    /// một khoảng hở cho phép bấm Export lần thứ hai.
    func testSearchablePDFExportSetsBusyFlagSynchronously() {
        let store = DocumentStore()
        let destination = FileManager.default.temporaryDirectory
            .appending(path: "azpdf-searchable-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: destination) }

        XCTAssertFalse(store.isSearchablePDFExporting)
        store.performSearchablePDFExport(documentData: Data("%PDF-1.4 fixture".utf8), to: destination)
        XCTAssertTrue(store.isSearchablePDFExporting, "cờ bận phải bật ngay, không đợi tác vụ nền")
        waitFor { !store.isSearchablePDFExporting }
    }
}
