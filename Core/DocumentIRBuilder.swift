import Foundation

public enum DocumentIRBuilder {
    /// Converts engine-level structured text into the semantic IR baseline.
    /// Tables/formulas remain ordinary text until an advanced provider replaces
    /// or enriches these blocks.
    public static func buildBaseline(
        layouts: [PDFPageTextLayout],
        pageDescriptors: [PDFPageDescriptor],
        metadata: DocumentIR.Metadata = .init(),
        provenance: DocumentIR.Provenance
    ) throws -> DocumentIR {
        var descriptors: [Int: PDFPageDescriptor] = [:]
        for descriptor in pageDescriptors {
            guard descriptors[descriptor.index] == nil else {
                throw DocumentIRBuilderError.duplicatePageDescriptor(descriptor.index)
            }
            descriptors[descriptor.index] = descriptor
        }
        var seenPages = Set<Int>()
        let pages = try layouts.map { layout -> DocumentIR.Page in
            guard seenPages.insert(layout.pageIndex).inserted else {
                throw DocumentIRBuilderError.duplicateLayoutPage(layout.pageIndex)
            }
            guard let descriptor = descriptors[layout.pageIndex] else {
                throw DocumentIRBuilderError.missingPageDescriptor(layout.pageIndex)
            }
            let size = DocumentIR.Geometry.visiblePageSize(
                cropBox: descriptor.cropBox,
                rotation: descriptor.rotation
            )
            let blocks = layout.blocks.enumerated().map { blockIndex, block in
                makeBlock(
                    block,
                    blockIndex: blockIndex,
                    pageIndex: layout.pageIndex,
                    coordinateSpace: layout.coordinateSpace,
                    descriptor: descriptor
                )
            }
            return DocumentIR.Page(
                index: layout.pageIndex,
                size: size,
                sourceRotation: descriptor.rotation,
                blocks: blocks,
                readingOrder: blocks.map(\.id)
            )
        }

        let document = DocumentIR(
            metadata: metadata,
            provenance: provenance,
            pages: pages
        )
        try document.validate()
        return document
    }

    private static func makeBlock(
        _ block: PDFTextBlock,
        blockIndex: Int,
        pageIndex: Int,
        coordinateSpace: PDFCoordinateSpace,
        descriptor: PDFPageDescriptor
    ) -> DocumentIR.Block {
        let id = "p\(pageIndex)-b\(blockIndex)"
        let lines = block.lines.enumerated().map { lineIndex, line in
            DocumentIR.TextLine(
                id: "\(id)-l\(lineIndex)",
                bounds: canonical(
                    line.bounds,
                    coordinateSpace: coordinateSpace,
                    descriptor: descriptor
                ),
                text: line.text
            )
        }

        switch block.kind {
        case .image:
            return DocumentIR.Block(
                id: id,
                kind: .figure,
                bounds: canonical(
                    block.bounds,
                    coordinateSpace: coordinateSpace,
                    descriptor: descriptor
                ),
                lines: lines,
                figure: .init(classification: "image")
            )
        case .text:
            let firstLine = block.lines.first
            return DocumentIR.Block(
                id: id,
                kind: .paragraph,
                bounds: canonical(
                    block.bounds,
                    coordinateSpace: coordinateSpace,
                    descriptor: descriptor
                ),
                lines: lines,
                style: firstLine.map {
                    DocumentIR.TextStyle(
                        fontFamily: $0.fontFamily ?? $0.fontName,
                        fontSize: $0.fontSize,
                        writingDirection: $0.writingMode == 1 ? .topToBottom : .leftToRight
                    )
                }
            )
        case .unknown:
            return DocumentIR.Block(
                id: id,
                kind: .unknown,
                bounds: canonical(
                    block.bounds,
                    coordinateSpace: coordinateSpace,
                    descriptor: descriptor
                ),
                lines: lines
            )
        }
    }

    private static func canonical(
        _ rect: PDFRect,
        coordinateSpace: PDFCoordinateSpace,
        descriptor: PDFPageDescriptor
    ) -> PDFRect {
        switch coordinateSpace {
        case .pageTopLeft:
            rect
        case .pdfBottomLeft:
            DocumentIR.Geometry.topLeftRect(
                fromPDFRect: rect,
                cropBox: descriptor.cropBox,
                rotation: descriptor.rotation
            )
        }
    }
}

public enum DocumentIRBuilderError: Error, Equatable, Sendable {
    case duplicateLayoutPage(Int)
    case duplicatePageDescriptor(Int)
    case missingPageDescriptor(Int)
}

extension DocumentIRBuilderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .duplicateLayoutPage(index):
            "Structured text chứa page index trùng: \(index)."
        case let .duplicatePageDescriptor(index):
            "Page descriptor chứa index trùng: \(index)."
        case let .missingPageDescriptor(index):
            "Thiếu page descriptor cho structured text trang \(index)."
        }
    }
}
