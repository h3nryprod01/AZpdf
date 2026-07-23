import XCTest
@testable import AZpdfCore

/// A "lying" engine: every `apply` call returns without throwing, but nothing
/// about the in-memory document ever actually changes. If the harness only
/// looked at whether `apply` threw, every case here would read `.supported`.
/// This proves it does not — postcondition read-back is what actually gates
/// `.supported`, which is the whole point of `PDFEngineOperationConformance`.
private final class LyingDocument {}

private struct LyingEngine: PDFDocumentReadingEngine {
    let capabilities: PDFEngineCapabilities = [
        .open, .save, .render, .extractText, .search, .metadata, .annotations
    ]

    func load(data: Data) throws -> LyingDocument { LyingDocument() }
    func dataRepresentation(of document: LyingDocument) throws -> Data { Data() }
    func pageCount(of document: LyingDocument) -> Int { 2 }

    /// Claims success for every operation without mutating `document`.
    func apply(_ operation: DocumentOperation, to document: LyingDocument) throws {}

    func metadata(of document: LyingDocument) throws -> PDFDocumentMetadata { PDFDocumentMetadata() }

    func pageDescriptor(at index: Int, in document: LyingDocument) throws -> PDFPageDescriptor {
        PDFPageDescriptor(
            index: index,
            mediaBox: PDFRect(x: 0, y: 0, width: 595, height: 842),
            cropBox: PDFRect(x: 0, y: 0, width: 595, height: 842),
            rotation: 0
        )
    }

    func text(ofPage index: Int, in document: LyingDocument) throws -> String {
        index == 0 ? "AZPDF-P1" : "AZPDF-P2"
    }

    func annotations(onPage index: Int, in document: LyingDocument) throws -> [PDFAnnotationDescriptor] { [] }

    func render(_ request: PDFRenderRequest, in document: LyingDocument) throws -> PDFRenderedPage {
        PDFRenderedPage(size: PDFSize(width: 1, height: 1), format: .png, data: Data([0x89]))
    }
}

final class OperationConformanceLyingEngineTests: XCTestCase {
    private func lyingReport() -> PDFOperationConformanceReport {
        PDFEngineOperationConformance.run(
            LyingEngine(),
            data: Data("fake-fixture".utf8),
            auxiliaryPDF: Data("fake-fixture".utf8),
            imagePNG: Data([0x89, 0x50, 0x4E, 0x47])
        )
    }

    func testHarnessCatchesEngineThatClaimsSuccessWithoutChangingRotation() {
        let rotate = lyingReport().result(for: "rotate")
        XCTAssertEqual(
            rotate?.status,
            .failed,
            "apply() không throw không có nghĩa là thao tác thật sự xảy ra — " +
            "rotation vẫn 0 sau 'rotate', harness phải phân loại .failed, nhận: \(String(describing: rotate))"
        )
    }

    /// Pins the guard's exact boundary, not just one case: 13/17 cases have a
    /// postcondition strong enough to catch a lying no-op engine. The remaining
    /// 4 pass vacuously BY DECLARED DESIGN (the plan's deliberately-weak
    /// round-trip postcondition, `ponytail:` comment in the harness) — if one
    /// of them moves into the caught set, or a caught case regresses into the
    /// vacuous set, this test goes red and the matrix's trustworthiness changed.
    func testGuardCoverageBoundaryAcrossAllSeventeenCases() {
        let report = lyingReport()

        let caught: Set<String> = [
            "rotate", "duplicate", "delete", "movePages", "insertPages",
            "addAnnotation", "redact", "insertDocument", "setMetadata",
            "upsertAnnotation", "upsertImageAnnotation", "removeAnnotation",
            "flattenAnnotations"
        ]
        let declaredWeak: Set<String> = [
            "setFormValue", "setOutline", "upsertEmbeddedFile", "removeEmbeddedFile"
        ]

        XCTAssertEqual(
            report.failedOperations,
            caught,
            "Tập case bắt được engine nói dối đã đổi — cập nhật test này VÀ ghi chú độ tin trong qa-report."
        )
        XCTAssertEqual(
            report.supportedOperations,
            declaredWeak,
            "Chỉ 4 case round-trip yếu-có-chủ-đích được phép 'supported' trên engine nói dối."
        )
        XCTAssertTrue(report.unsupportedOperations.isEmpty)
    }
}
