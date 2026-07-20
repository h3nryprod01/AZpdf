import Foundation

public struct PDFEngineConformanceIssue: Codable, Equatable, Sendable {
    public enum Code: String, Codable, Sendable {
        case missingCapabilities
        case emptyDocument
        case metadataFailure
        case pageReadFailure
        case pageIndexMismatch
        case invalidMediaBox
        case invalidCropBox
        case invalidRotation
        case annotationPageMismatch
        case emptyRender
    }

    public let code: Code
    public let pageIndex: Int?
    public let detail: String

    public init(code: Code, pageIndex: Int? = nil, detail: String) {
        self.code = code
        self.pageIndex = pageIndex
        self.detail = detail
    }
}

public struct PDFEngineConformanceReport: Codable, Equatable, Sendable {
    public let pageCount: Int
    public let issues: [PDFEngineConformanceIssue]

    public init(pageCount: Int, issues: [PDFEngineConformanceIssue]) {
        self.pageCount = pageCount
        self.issues = issues
    }

    public var isConformant: Bool { issues.isEmpty }
}

/// Shared behavioral gate for PDFKit, MuPDF and future adapters.
public enum PDFEngineConformance {
    public static func validate<Engine: PDFDocumentReadingEngine>(
        _ engine: Engine,
        document: Engine.Document,
        renderScale: Double = 0.25
    ) -> PDFEngineConformanceReport {
        var issues: [PDFEngineConformanceIssue] = []
        let required: PDFEngineCapabilities = [
            .open, .save, .render, .extractText, .search, .metadata, .annotations
        ]
        let missing = required.subtracting(engine.capabilities)
        if !missing.isEmpty {
            issues.append(.init(
                code: .missingCapabilities,
                detail: "Thiếu capability rawValue=\(missing.rawValue)."
            ))
        }

        let count = engine.pageCount(of: document)
        if count == 0 {
            issues.append(.init(code: .emptyDocument, detail: "Tài liệu không có trang."))
        }

        do {
            _ = try engine.metadata(of: document)
        } catch {
            issues.append(.init(code: .metadataFailure, detail: String(describing: error)))
        }

        for pageIndex in 0..<count {
            do {
                let page = try engine.pageDescriptor(at: pageIndex, in: document)
                if page.index != pageIndex {
                    issues.append(.init(
                        code: .pageIndexMismatch,
                        pageIndex: pageIndex,
                        detail: "Engine trả index \(page.index)."
                    ))
                }
                if page.mediaBox.isEmpty {
                    issues.append(.init(code: .invalidMediaBox, pageIndex: pageIndex, detail: "MediaBox rỗng."))
                }
                if page.cropBox.isEmpty {
                    issues.append(.init(code: .invalidCropBox, pageIndex: pageIndex, detail: "CropBox rỗng."))
                }
                if page.rotation % 90 != 0 {
                    issues.append(.init(
                        code: .invalidRotation,
                        pageIndex: pageIndex,
                        detail: "Rotation \(page.rotation) không chia hết cho 90."
                    ))
                }

                _ = try engine.text(ofPage: pageIndex, in: document)
                let annotations = try engine.annotations(onPage: pageIndex, in: document)
                for annotation in annotations where annotation.pageIndex != pageIndex {
                    issues.append(.init(
                        code: .annotationPageMismatch,
                        pageIndex: pageIndex,
                        detail: "Annotation \(annotation.id) trỏ tới trang \(annotation.pageIndex)."
                    ))
                }

                let rendered = try engine.render(
                    PDFRenderRequest(pageIndex: pageIndex, scale: max(0.05, renderScale)),
                    in: document
                )
                if rendered.data.isEmpty || rendered.size.width <= 0 || rendered.size.height <= 0 {
                    issues.append(.init(code: .emptyRender, pageIndex: pageIndex, detail: "Render rỗng."))
                }
            } catch {
                issues.append(.init(
                    code: .pageReadFailure,
                    pageIndex: pageIndex,
                    detail: String(describing: error)
                ))
            }
        }

        return PDFEngineConformanceReport(pageCount: count, issues: issues)
    }
}
