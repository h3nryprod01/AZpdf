import Foundation

/// Outcome of applying one `DocumentOperation` case against an engine.
public struct PDFOperationConformanceResult: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        /// `apply` did not throw and the read-back postcondition matched.
        case supported
        /// `apply` threw `PDFEngineError.operationNotSupported`.
        case unsupported
        /// `apply` threw something else, or it returned normally while the
        /// read-back postcondition disagreed — the engine claimed success
        /// but the document does not show it.
        case failed
    }

    public let operation: String
    public let status: Status
    public let detail: String

    public init(operation: String, status: Status, detail: String) {
        self.operation = operation
        self.status = status
        self.detail = detail
    }
}

public struct PDFOperationConformanceReport: Codable, Equatable, Sendable {
    public let results: [PDFOperationConformanceResult]

    public init(results: [PDFOperationConformanceResult]) {
        self.results = results
    }

    public func result(for operation: String) -> PDFOperationConformanceResult? {
        results.first { $0.operation == operation }
    }

    public var supportedOperations: Set<String> {
        operations(withStatus: .supported)
    }

    public var unsupportedOperations: Set<String> {
        operations(withStatus: .unsupported)
    }

    public var failedOperations: Set<String> {
        operations(withStatus: .failed)
    }

    private func operations(withStatus status: PDFOperationConformanceResult.Status) -> Set<String> {
        Set(results.filter { $0.status == status }.map(\.operation))
    }
}

/// Runs every `DocumentOperation` case against an engine and classifies the
/// result from what the engine actually did, not from what it claims: a case
/// that returns without throwing but leaves the read-back postcondition wrong
/// is `.failed`, the same bucket as a case that throws an unexpected error.
/// Only a thrown `PDFEngineError.operationNotSupported` counts as `.unsupported`.
///
/// `PDFDocumentEngine.Document` is `AnyObject` and `apply` mutates it in
/// place, so every case loads its own document fresh from `data` — cases
/// never share state or contaminate each other.
public enum PDFEngineOperationConformance {
    private static let markerPage1 = "AZPDF-P1"
    private static let markerPage2 = "AZPDF-P2"

    /// - Parameters:
    ///   - data: The fixture document (expected: 2 pages, page 0 contains
    ///     `AZPDF-P1`, page 1 contains `AZPDF-P2`).
    ///   - auxiliaryPDF: A second document to merge in for `insertDocument`.
    ///     The fixture itself works fine here.
    ///   - imagePNG: A minimal valid PNG for `upsertImageAnnotation`.
    public static func run<Engine: PDFDocumentReadingEngine>(
        _ engine: Engine,
        data: Data,
        auxiliaryPDF: Data,
        imagePNG: Data
    ) -> PDFOperationConformanceReport {
        let cases: [OperationCase<Engine>] = operationCases(auxiliaryPDF: auxiliaryPDF, imagePNG: imagePNG)
        return PDFOperationConformanceReport(
            results: cases.map { classify($0, engine: engine, data: data) }
        )
    }

    private static func classify<Engine: PDFDocumentReadingEngine>(
        _ operationCase: OperationCase<Engine>,
        engine: Engine,
        data: Data
    ) -> PDFOperationConformanceResult {
        let document: Engine.Document
        do {
            document = try engine.load(data: data)
        } catch {
            return PDFOperationConformanceResult(
                operation: operationCase.name,
                status: .failed,
                detail: "Không load được fixture gốc: \(error)"
            )
        }

        // Setup (e.g. removeAnnotation needs something to remove first). A
        // setup failure does not block the target operation — but if apply
        // then CLAIMS success, the case is `.failed`: absence-postconditions
        // ("annotation gone", "page empty") are vacuously true on a document
        // the setup never populated, so a claimed success is unverifiable.
        var prepareFailure: Error?
        if let prepare = operationCase.prepare {
            do {
                try prepare(engine, document)
            } catch {
                prepareFailure = error
            }
        }

        do {
            try engine.apply(operationCase.operation, to: document)
        } catch PDFEngineError.operationNotSupported {
            return PDFOperationConformanceResult(
                operation: operationCase.name,
                status: .unsupported,
                detail: "apply ném PDFEngineError.operationNotSupported"
            )
        } catch {
            return PDFOperationConformanceResult(
                operation: operationCase.name,
                status: .failed,
                detail: "apply ném lỗi không mong đợi: \(error)"
            )
        }

        if let prepareFailure {
            return PDFOperationConformanceResult(
                operation: operationCase.name,
                status: .failed,
                detail: "apply báo thành công nhưng bước chuẩn bị thất bại (\(prepareFailure)) — "
                    + "postcondition vắng-mặt sẽ đúng một cách rỗng, không kiểm chứng được."
            )
        }

        do {
            try operationCase.verify(engine, document)
            return PDFOperationConformanceResult(
                operation: operationCase.name,
                status: .supported,
                detail: "apply không throw và postcondition đọc lại đúng"
            )
        } catch let mismatch as PostconditionMismatch {
            return PDFOperationConformanceResult(operation: operationCase.name, status: .failed, detail: mismatch.detail)
        } catch {
            return PDFOperationConformanceResult(
                operation: operationCase.name,
                status: .failed,
                detail: "đọc lại postcondition ném lỗi: \(error)"
            )
        }
    }

    private static func operationCases<Engine: PDFDocumentReadingEngine>(
        auxiliaryPDF: Data,
        imagePNG: Data
    ) -> [OperationCase<Engine>] {
        let upsertDescriptor = PDFAnnotationDescriptor(
            id: "op-conformance-upsert",
            kind: .freeText,
            pageIndex: 0,
            bounds: PDFRect(x: 72, y: 500, width: 200, height: 60),
            contents: "Op conformance upsert"
        )
        let imageDescriptor = PDFAnnotationDescriptor(
            id: "op-conformance-image",
            kind: .image,
            pageIndex: 0,
            bounds: PDFRect(x: 72, y: 400, width: 80, height: 80)
        )
        let removeTargetDescriptor = PDFAnnotationDescriptor(
            id: "op-conformance-remove-target",
            kind: .freeText,
            pageIndex: 0,
            bounds: PDFRect(x: 72, y: 300, width: 200, height: 60),
            contents: "Op conformance remove target"
        )
        let outlineItem = PDFOutlineItem(id: "op-conformance-outline", title: "Op conformance", pageIndex: 0)
        let embeddedFile = PDFEmbeddedFileDescriptor(
            id: "op-conformance-file",
            filename: "op-conformance.txt",
            mimeType: "text/plain"
        )

        return [
            OperationCase(
                name: "rotate",
                operation: .rotate(page: 0),
                verify: { engine, document in
                    let rotation = try engine.pageDescriptor(at: 0, in: document).rotation
                    guard rotation == 90 else {
                        throw PostconditionMismatch(detail: "Kỳ vọng rotation trang 0 = 90, nhận \(rotation).")
                    }
                }
            ),
            OperationCase(
                name: "duplicate",
                operation: .duplicate(page: 0),
                verify: { engine, document in
                    try expectPageCount(3, engine: engine, document: document, context: "sau duplicate")
                    // Bản sao phải nằm ở page+1 (hợp đồng de-facto: PDFKit adapter và
                    // fake engine trong PortableDocumentSessionTests đều insert tại page+1)
                    // và phải là bản sao của ĐÚNG trang 0 — đếm trang không đủ.
                    try expectText(containing: markerPage1, onPage: 1, engine: engine, document: document, context: "sau duplicate(0)")
                    try expectText(containing: markerPage2, onPage: 2, engine: engine, document: document, context: "sau duplicate(0)")
                }
            ),
            OperationCase(
                name: "delete",
                operation: .delete(page: 0),
                verify: { engine, document in
                    try expectPageCount(1, engine: engine, document: document, context: "sau delete")
                    // Trang còn lại phải là trang 1 cũ — xóa nhầm trang vẫn ra pageCount 1.
                    try expectText(containing: markerPage2, onPage: 0, engine: engine, document: document, context: "sau delete(0)")
                }
            ),
            OperationCase(
                name: "movePages",
                operation: .movePages(from: [0], destination: 2),
                verify: { engine, document in
                    let text = try engine.text(ofPage: 0, in: document)
                    guard text.contains(markerPage2) else {
                        throw PostconditionMismatch(
                            detail: "Kỳ vọng trang 0 chứa \(markerPage2) sau movePages, text đọc được: \(text)"
                        )
                    }
                }
            ),
            OperationCase(
                name: "insertPages",
                operation: .insertPages(count: 1, at: 1),
                verify: { engine, document in
                    try expectPageCount(3, engine: engine, document: document, context: "sau insertPages")
                    // Nội dung trang chèn không thuộc contract (store chèn trang từ file
                    // ngoài), nhưng vị trí thì có: hai trang gốc phải giạt ra quanh index 1.
                    try expectText(containing: markerPage1, onPage: 0, engine: engine, document: document, context: "sau insertPages(1, at: 1)")
                    try expectText(containing: markerPage2, onPage: 2, engine: engine, document: document, context: "sau insertPages(1, at: 1)")
                }
            ),
            OperationCase(
                name: "addAnnotation",
                operation: .addAnnotation(kind: .note, page: 0),
                verify: { engine, document in
                    let annotations = try engine.annotations(onPage: 0, in: document)
                    guard annotations.contains(where: { $0.kind == .note }) else {
                        throw PostconditionMismatch(detail: "Không thấy annotation kind .note mới trên trang 0.")
                    }
                }
            ),
            OperationCase(
                name: "redact",
                operation: .redact(pages: [0]),
                verify: { engine, document in
                    let text = try engine.text(ofPage: 0, in: document)
                    guard !text.contains(markerPage1) else {
                        throw PostconditionMismatch(detail: "Redact xong nhưng \(markerPage1) vẫn còn trong text trang 0.")
                    }
                }
            ),
            OperationCase(
                name: "insertDocument",
                operation: .insertDocument(data: auxiliaryPDF, pages: nil, at: 2),
                verify: { engine, document in
                    try expectPageCount(4, engine: engine, document: document, context: "sau insertDocument (2 gốc + 2 chèn)")
                    // auxiliaryPDF là chính fixture 2 trang → trang 2-3 phải là P1, P2
                    // theo đúng thứ tự; chèn nhầm nguồn/vị trí vẫn ra pageCount 4.
                    try expectText(containing: markerPage1, onPage: 2, engine: engine, document: document, context: "sau insertDocument(at: 2)")
                    try expectText(containing: markerPage2, onPage: 3, engine: engine, document: document, context: "sau insertDocument(at: 2)")
                }
            ),
            OperationCase(
                name: "setMetadata",
                operation: .setMetadata(PDFDocumentMetadata(title: "AZpdf Conformance")),
                verify: { engine, document in
                    let title = try engine.metadata(of: document).title
                    guard title == "AZpdf Conformance" else {
                        throw PostconditionMismatch(
                            detail: "Kỳ vọng metadata.title = 'AZpdf Conformance', đọc lại: \(title ?? "nil")"
                        )
                    }
                }
            ),
            OperationCase(
                name: "upsertAnnotation",
                operation: .upsertAnnotation(upsertDescriptor),
                verify: { engine, document in
                    try expectAnnotationPresent(upsertDescriptor.id, onPage: 0, engine: engine, document: document)
                }
            ),
            OperationCase(
                name: "upsertImageAnnotation",
                operation: .upsertImageAnnotation(imageDescriptor, imageData: imagePNG, format: .png),
                verify: { engine, document in
                    try expectAnnotationPresent(imageDescriptor.id, onPage: 0, engine: engine, document: document)
                }
            ),
            OperationCase(
                name: "removeAnnotation",
                operation: .removeAnnotation(id: removeTargetDescriptor.id, page: 0),
                prepare: { engine, document in
                    try engine.apply(.upsertAnnotation(removeTargetDescriptor), to: document)
                    // Precondition: mục tiêu phải THẬT SỰ tồn tại trước khi remove —
                    // nếu không, "id biến mất" đúng một cách rỗng trên engine no-op.
                    try expectAnnotationPresent(removeTargetDescriptor.id, onPage: 0, engine: engine, document: document)
                },
                verify: { engine, document in
                    let annotations = try engine.annotations(onPage: 0, in: document)
                    guard !annotations.contains(where: { $0.id == removeTargetDescriptor.id }) else {
                        throw PostconditionMismatch(
                            detail: "Annotation id \(removeTargetDescriptor.id) vẫn còn sau removeAnnotation."
                        )
                    }
                }
            ),
            OperationCase(
                name: "flattenAnnotations",
                operation: .flattenAnnotations(pages: [0]),
                prepare: { engine, document in
                    // Seed một annotation để "annotations rỗng sau flatten" không đúng
                    // một cách rỗng trên fixture vốn không có annotation nào.
                    try engine.apply(.upsertAnnotation(upsertDescriptor), to: document)
                    try expectAnnotationPresent(upsertDescriptor.id, onPage: 0, engine: engine, document: document)
                },
                verify: { engine, document in
                    let annotations = try engine.annotations(onPage: 0, in: document)
                    guard annotations.isEmpty else {
                        throw PostconditionMismatch(
                            detail: "annotations(onPage:0) còn \(annotations.count) phần tử sau flatten."
                        )
                    }
                }
            ),
            // setFormValue/setOutline/upsertEmbeddedFile/removeEmbeddedFile: the
            // fixture has no pre-existing form field/outline/attachment, so
            // there is nothing to pin a strict postcondition against yet.
            // ponytail: verify only that a claimed success survives a
            // dataRepresentation round trip — tighten this once 2g wires a
            // real implementation with a fixture that has the matching state.
            OperationCase(
                name: "setFormValue",
                operation: .setFormValue(fieldID: "op-conformance-field", value: "value"),
                verify: roundTripVerify()
            ),
            OperationCase(
                name: "setOutline",
                operation: .setOutline([outlineItem]),
                verify: roundTripVerify()
            ),
            OperationCase(
                name: "upsertEmbeddedFile",
                operation: .upsertEmbeddedFile(embeddedFile, data: Data("AZpdf conformance".utf8)),
                verify: roundTripVerify()
            ),
            OperationCase(
                name: "removeEmbeddedFile",
                operation: .removeEmbeddedFile(id: embeddedFile.id),
                verify: roundTripVerify()
            )
        ]
    }

    private static func expectPageCount<Engine: PDFDocumentReadingEngine>(
        _ expected: Int,
        engine: Engine,
        document: Engine.Document,
        context: String
    ) throws {
        let count = engine.pageCount(of: document)
        guard count == expected else {
            throw PostconditionMismatch(detail: "Kỳ vọng pageCount \(expected) \(context), nhận \(count).")
        }
    }

    private static func expectText<Engine: PDFDocumentReadingEngine>(
        containing marker: String,
        onPage page: Int,
        engine: Engine,
        document: Engine.Document,
        context: String
    ) throws {
        let text = try engine.text(ofPage: page, in: document)
        guard text.contains(marker) else {
            throw PostconditionMismatch(
                detail: "Kỳ vọng trang \(page) chứa \(marker) \(context), text đọc được: \(text)"
            )
        }
    }

    private static func expectAnnotationPresent<Engine: PDFDocumentReadingEngine>(
        _ id: String,
        onPage page: Int,
        engine: Engine,
        document: Engine.Document
    ) throws {
        let annotations = try engine.annotations(onPage: page, in: document)
        guard annotations.contains(where: { $0.id == id }) else {
            throw PostconditionMismatch(detail: "Không thấy annotation id \(id) trên trang \(page).")
        }
    }

    private static func roundTripVerify<Engine: PDFDocumentReadingEngine>() -> (Engine, Engine.Document) throws -> Void {
        { engine, document in
            let data = try engine.dataRepresentation(of: document)
            _ = try engine.load(data: data)
        }
    }

    /// Compile-time canary: thêm case mới vào `DocumentOperation` làm switch này
    /// hết exhaustive → không compile — buộc ma trận ở `operationCases` phủ case
    /// mới trước khi build xanh trở lại. (Không được gọi lúc chạy; chỉ để compiler
    /// kiểm. Đếm `results.count` trong test không làm được việc này vì harness tự
    /// liệt kê case của nó, không đọc từ enum.)
    private static func exhaustivenessCanary(_ operation: DocumentOperation) {
        switch operation {
        case .rotate, .duplicate, .delete, .movePages, .insertPages, .addAnnotation,
             .redact, .insertDocument, .setMetadata, .upsertAnnotation,
             .upsertImageAnnotation, .removeAnnotation, .flattenAnnotations,
             .setFormValue, .setOutline, .upsertEmbeddedFile, .removeEmbeddedFile:
            break
        }
    }
}

private struct OperationCase<Engine: PDFDocumentReadingEngine> {
    let name: String
    let operation: DocumentOperation
    let prepare: ((Engine, Engine.Document) throws -> Void)?
    let verify: (Engine, Engine.Document) throws -> Void

    init(
        name: String,
        operation: DocumentOperation,
        prepare: ((Engine, Engine.Document) throws -> Void)? = nil,
        verify: @escaping (Engine, Engine.Document) throws -> Void
    ) {
        self.name = name
        self.operation = operation
        self.prepare = prepare
        self.verify = verify
    }
}

private struct PostconditionMismatch: Error {
    let detail: String
}
