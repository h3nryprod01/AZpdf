import Foundation

/// Provider-neutral representation of document semantics discovered by OCR.
/// Geometry is canonicalized to PDF points with a top-left origin so OCR
/// providers and cross-platform shells do not need to guess coordinate axes.
public struct DocumentIR: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var metadata: Metadata
    public var provenance: Provenance
    public var pages: [Page]
    public var relations: [Relation]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        metadata: Metadata = .init(),
        provenance: Provenance,
        pages: [Page],
        relations: [Relation] = []
    ) {
        self.schemaVersion = schemaVersion
        self.metadata = metadata
        self.provenance = provenance
        self.pages = pages
        self.relations = relations
    }

    public var plainText: String {
        pages.sorted { $0.index < $1.index }
            .map(\.plainText)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    public func validate() throws {
        guard (1...Self.currentSchemaVersion).contains(schemaVersion) else {
            throw DocumentIRValidationError.unsupportedSchemaVersion(schemaVersion)
        }

        var pageIndexes = Set<Int>()
        var documentBlockIDs = Set<String>()
        for page in pages {
            guard page.index >= 0, pageIndexes.insert(page.index).inserted else {
                throw DocumentIRValidationError.duplicateOrInvalidPageIndex(page.index)
            }
            try page.validate(documentBlockIDs: &documentBlockIDs)
        }

        for block in pages.flatMap(\.blocks) {
            guard let figure = block.figure else { continue }
            var captionIDs = Set<String>()
            for captionBlockID in figure.captionBlockIDs {
                guard documentBlockIDs.contains(captionBlockID),
                      captionIDs.insert(captionBlockID).inserted else {
                    throw DocumentIRValidationError.invalidFigureCaptionReference(
                        figureBlockID: block.id,
                        captionBlockID: captionBlockID
                    )
                }
            }
        }

        for relation in relations {
            guard documentBlockIDs.contains(relation.sourceBlockID) else {
                throw DocumentIRValidationError.missingRelationEndpoint(relation.sourceBlockID)
            }
            guard documentBlockIDs.contains(relation.targetBlockID) else {
                throw DocumentIRValidationError.missingRelationEndpoint(relation.targetBlockID)
            }
        }
    }
}

public extension DocumentIR {
    struct Metadata: Codable, Equatable, Sendable {
        public var title: String?
        public var sourceFilename: String?
        public var sourceSHA256: String?
        public var primaryLanguage: String?

        public init(
            title: String? = nil,
            sourceFilename: String? = nil,
            sourceSHA256: String? = nil,
            primaryLanguage: String? = nil
        ) {
            self.title = title
            self.sourceFilename = sourceFilename
            self.sourceSHA256 = sourceSHA256
            self.primaryLanguage = primaryLanguage
        }
    }

    struct Provenance: Codable, Equatable, Sendable {
        public var providerID: String
        public var providerVersion: String?
        public var modelID: String?
        public var modelVersion: String?
        public var generatedAtRFC3339: String?
        public var languages: [String]
        public var options: [String: String]

        public init(
            providerID: String,
            providerVersion: String? = nil,
            modelID: String? = nil,
            modelVersion: String? = nil,
            generatedAtRFC3339: String? = nil,
            languages: [String] = [],
            options: [String: String] = [:]
        ) {
            self.providerID = providerID
            self.providerVersion = providerVersion
            self.modelID = modelID
            self.modelVersion = modelVersion
            self.generatedAtRFC3339 = generatedAtRFC3339
            self.languages = languages
            self.options = options
        }
    }

    enum CoordinateSpace: String, Codable, Sendable {
        /// Units are PDF points. Origin is the visible page's top-left; +x moves
        /// right and +y moves down. Rotation has already been normalized.
        case pagePointsTopLeft
    }

    struct Page: Codable, Equatable, Sendable {
        public var index: Int
        public var size: PDFSize
        public var sourceRotation: Int
        public var coordinateSpace: CoordinateSpace
        public var sourceImageSHA256: String?
        public var detectedLanguages: [String]
        public var blocks: [Block]
        public var readingOrder: [String]

        public init(
            index: Int,
            size: PDFSize,
            sourceRotation: Int = 0,
            coordinateSpace: CoordinateSpace = .pagePointsTopLeft,
            sourceImageSHA256: String? = nil,
            detectedLanguages: [String] = [],
            blocks: [Block],
            readingOrder: [String] = []
        ) {
            self.index = index
            self.size = size
            self.sourceRotation = ((sourceRotation % 360) + 360) % 360
            self.coordinateSpace = coordinateSpace
            self.sourceImageSHA256 = sourceImageSHA256
            self.detectedLanguages = detectedLanguages
            self.blocks = blocks
            self.readingOrder = readingOrder
        }

        public var plainText: String {
            var byID: [String: Block] = [:]
            for block in blocks where byID[block.id] == nil { byID[block.id] = block }
            let ordered = readingOrder.compactMap { byID[$0] }
            let orderedIDs = Set(ordered.map(\.id))
            let remaining = blocks.filter { !orderedIDs.contains($0.id) }.sorted {
                if $0.bounds.origin.y == $1.bounds.origin.y {
                    return $0.bounds.origin.x < $1.bounds.origin.x
                }
                return $0.bounds.origin.y < $1.bounds.origin.y
            }
            return (ordered + remaining)
                .filter { !$0.isArtifact }
                .map(\.plainText)
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }

        fileprivate func validate(documentBlockIDs: inout Set<String>) throws {
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                throw DocumentIRValidationError.invalidPageSize(index)
            }
            guard [0, 90, 180, 270].contains(sourceRotation) else {
                throw DocumentIRValidationError.invalidPageRotation(index, sourceRotation)
            }

            var pageBlockIDs = Set<String>()
            for block in blocks {
                guard !block.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      pageBlockIDs.insert(block.id).inserted,
                      documentBlockIDs.insert(block.id).inserted else {
                    throw DocumentIRValidationError.duplicateOrEmptyBlockID(block.id)
                }
                try block.validate(pageIndex: index, pageSize: size)
            }

            var orderedIDs = Set<String>()
            for blockID in readingOrder {
                guard pageBlockIDs.contains(blockID) else {
                    throw DocumentIRValidationError.missingReadingOrderBlock(page: index, blockID: blockID)
                }
                guard orderedIDs.insert(blockID).inserted else {
                    throw DocumentIRValidationError.duplicateReadingOrderBlock(page: index, blockID: blockID)
                }
            }
        }
    }

    enum BlockKind: String, Codable, CaseIterable, Sendable {
        case paragraph
        case heading
        case listItem
        case table
        case formula
        case figure
        case caption
        case header
        case footer
        case footnote
        case pageNumber
        case unknown
    }

    struct Block: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var kind: BlockKind
        public var bounds: PDFRect
        public var confidence: Double?
        public var language: String?
        public var isArtifact: Bool
        public var text: String?
        public var lines: [TextLine]
        public var style: TextStyle?
        public var table: Table?
        public var formula: Formula?
        public var figure: Figure?

        public init(
            id: String,
            kind: BlockKind,
            bounds: PDFRect,
            confidence: Double? = nil,
            language: String? = nil,
            isArtifact: Bool = false,
            text: String? = nil,
            lines: [TextLine] = [],
            style: TextStyle? = nil,
            table: Table? = nil,
            formula: Formula? = nil,
            figure: Figure? = nil
        ) {
            self.id = id
            self.kind = kind
            self.bounds = bounds
            self.confidence = confidence
            self.language = language
            self.isArtifact = isArtifact
            self.text = text
            self.lines = lines
            self.style = style
            self.table = table
            self.formula = formula
            self.figure = figure
        }

        public var plainText: String {
            if let text, !text.isEmpty { return text }
            if !lines.isEmpty {
                return lines.map(\.plainText).filter { !$0.isEmpty }.joined(separator: "\n")
            }
            if let table { return table.plainText }
            if let formula { return formula.latex ?? formula.mathML ?? "" }
            if let figure { return figure.altText ?? "" }
            return ""
        }

        fileprivate func validate(pageIndex: Int, pageSize: PDFSize) throws {
            try DocumentIR.validate(bounds, pageIndex: pageIndex, pageSize: pageSize, ownerID: id)
            try DocumentIR.validate(confidence, ownerID: id)
            var lineIDs = Set<String>()
            for line in lines {
                guard lineIDs.insert(line.id).inserted else {
                    throw DocumentIRValidationError.duplicateOrEmptyLineID(line.id)
                }
                try line.validate(pageIndex: pageIndex, pageSize: pageSize, blockID: id)
            }

            switch kind {
            case .table:
                guard let table, formula == nil, figure == nil else {
                    throw DocumentIRValidationError.incompatiblePayload(blockID: id, kind: kind)
                }
                try table.validate(blockID: id, pageIndex: pageIndex, pageSize: pageSize)
            case .formula:
                guard let formula, table == nil, figure == nil,
                      formula.latex?.isEmpty == false || formula.mathML?.isEmpty == false else {
                    throw DocumentIRValidationError.incompatiblePayload(blockID: id, kind: kind)
                }
                try DocumentIR.validate(formula.confidence, ownerID: id)
            case .figure:
                guard figure != nil, table == nil, formula == nil else {
                    throw DocumentIRValidationError.incompatiblePayload(blockID: id, kind: kind)
                }
            default:
                guard table == nil, formula == nil, figure == nil else {
                    throw DocumentIRValidationError.incompatiblePayload(blockID: id, kind: kind)
                }
            }
        }
    }

    struct TextLine: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var bounds: PDFRect
        public var text: String?
        public var confidence: Double?
        public var words: [Word]

        public init(
            id: String,
            bounds: PDFRect,
            text: String? = nil,
            confidence: Double? = nil,
            words: [Word] = []
        ) {
            self.id = id
            self.bounds = bounds
            self.text = text
            self.confidence = confidence
            self.words = words
        }

        public var plainText: String {
            if let text, !text.isEmpty { return text }
            return words.map(\.text).joined(separator: " ")
        }

        fileprivate func validate(pageIndex: Int, pageSize: PDFSize, blockID: String) throws {
            guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DocumentIRValidationError.duplicateOrEmptyLineID(id)
            }
            try DocumentIR.validate(bounds, pageIndex: pageIndex, pageSize: pageSize, ownerID: id)
            try DocumentIR.validate(confidence, ownerID: id)
            var wordIDs = Set<String>()
            for word in words {
                guard !word.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      wordIDs.insert(word.id).inserted else {
                    throw DocumentIRValidationError.duplicateOrEmptyWordID(blockID: blockID, wordID: word.id)
                }
                try word.validate(pageIndex: pageIndex, pageSize: pageSize)
            }
        }
    }

    struct Word: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var text: String
        public var quad: Quad
        public var confidence: Double?
        public var alternatives: [String]

        public init(
            id: String,
            text: String,
            quad: Quad,
            confidence: Double? = nil,
            alternatives: [String] = []
        ) {
            self.id = id
            self.text = text
            self.quad = quad
            self.confidence = confidence
            self.alternatives = alternatives
        }

        fileprivate func validate(pageIndex: Int, pageSize: PDFSize) throws {
            try DocumentIR.validate(confidence, ownerID: id)
            for point in quad.points {
                guard point.x.isFinite, point.y.isFinite,
                      point.x >= 0, point.y >= 0,
                      point.x <= pageSize.width, point.y <= pageSize.height else {
                    throw DocumentIRValidationError.invalidGeometry(page: pageIndex, ownerID: id)
                }
            }
        }
    }

    struct Quad: Codable, Equatable, Sendable {
        public var topLeft: PDFPoint
        public var topRight: PDFPoint
        public var bottomRight: PDFPoint
        public var bottomLeft: PDFPoint

        public init(topLeft: PDFPoint, topRight: PDFPoint, bottomRight: PDFPoint, bottomLeft: PDFPoint) {
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomRight = bottomRight
            self.bottomLeft = bottomLeft
        }

        public init(rect: PDFRect) {
            let minX = rect.origin.x
            let minY = rect.origin.y
            let maxX = minX + rect.size.width
            let maxY = minY + rect.size.height
            self.init(
                topLeft: PDFPoint(x: minX, y: minY),
                topRight: PDFPoint(x: maxX, y: minY),
                bottomRight: PDFPoint(x: maxX, y: maxY),
                bottomLeft: PDFPoint(x: minX, y: maxY)
            )
        }

        fileprivate var points: [PDFPoint] { [topLeft, topRight, bottomRight, bottomLeft] }
    }

    struct TextStyle: Codable, Equatable, Sendable {
        public enum Alignment: String, Codable, Sendable { case leading, center, trailing, justified }
        public enum WritingDirection: String, Codable, Sendable { case leftToRight, rightToLeft, topToBottom }

        public var fontFamily: String?
        public var fontSize: Double?
        public var fontWeight: Int?
        public var italic: Bool?
        public var underline: Bool?
        public var color: PDFColor?
        public var alignment: Alignment?
        public var writingDirection: WritingDirection?

        public init(
            fontFamily: String? = nil,
            fontSize: Double? = nil,
            fontWeight: Int? = nil,
            italic: Bool? = nil,
            underline: Bool? = nil,
            color: PDFColor? = nil,
            alignment: Alignment? = nil,
            writingDirection: WritingDirection? = nil
        ) {
            self.fontFamily = fontFamily
            self.fontSize = fontSize
            self.fontWeight = fontWeight
            self.italic = italic
            self.underline = underline
            self.color = color
            self.alignment = alignment
            self.writingDirection = writingDirection
        }
    }

    struct Table: Codable, Equatable, Sendable {
        public var rowCount: Int
        public var columnCount: Int
        public var cells: [TableCell]

        public init(rowCount: Int, columnCount: Int, cells: [TableCell]) {
            self.rowCount = rowCount
            self.columnCount = columnCount
            self.cells = cells
        }

        public var plainText: String {
            (0..<rowCount).map { row in
                cells.filter { $0.row == row }
                    .sorted { $0.column < $1.column }
                    .map(\.text)
                    .joined(separator: "\t")
            }.joined(separator: "\n")
        }

        fileprivate func validate(blockID: String, pageIndex: Int, pageSize: PDFSize) throws {
            guard rowCount > 0, columnCount > 0 else {
                throw DocumentIRValidationError.invalidTable(blockID: blockID)
            }
            var origins = Set<String>()
            for cell in cells {
                guard cell.row >= 0, cell.column >= 0,
                      cell.rowSpan > 0, cell.columnSpan > 0,
                      cell.row + cell.rowSpan <= rowCount,
                      cell.column + cell.columnSpan <= columnCount,
                      origins.insert("\(cell.row):\(cell.column)").inserted else {
                    throw DocumentIRValidationError.invalidTable(blockID: blockID)
                }
                try DocumentIR.validate(cell.bounds, pageIndex: pageIndex, pageSize: pageSize, ownerID: blockID)
                try DocumentIR.validate(cell.confidence, ownerID: blockID)
            }
        }
    }

    struct TableCell: Codable, Equatable, Sendable {
        public var row: Int
        public var column: Int
        public var rowSpan: Int
        public var columnSpan: Int
        public var bounds: PDFRect
        public var text: String
        public var confidence: Double?

        public init(
            row: Int,
            column: Int,
            rowSpan: Int = 1,
            columnSpan: Int = 1,
            bounds: PDFRect,
            text: String,
            confidence: Double? = nil
        ) {
            self.row = row
            self.column = column
            self.rowSpan = rowSpan
            self.columnSpan = columnSpan
            self.bounds = bounds
            self.text = text
            self.confidence = confidence
        }
    }

    struct Formula: Codable, Equatable, Sendable {
        public var latex: String?
        public var mathML: String?
        public var confidence: Double?

        public init(latex: String? = nil, mathML: String? = nil, confidence: Double? = nil) {
            self.latex = latex
            self.mathML = mathML
            self.confidence = confidence
        }
    }

    struct Figure: Codable, Equatable, Sendable {
        public var altText: String?
        public var classification: String?
        public var imageSHA256: String?
        public var captionBlockIDs: [String]

        public init(
            altText: String? = nil,
            classification: String? = nil,
            imageSHA256: String? = nil,
            captionBlockIDs: [String] = []
        ) {
            self.altText = altText
            self.classification = classification
            self.imageSHA256 = imageSHA256
            self.captionBlockIDs = captionBlockIDs
        }
    }

    enum RelationKind: String, Codable, CaseIterable, Sendable {
        case captionOf
        case footnoteOf
        case continuationOf
        case labelFor
        case readingOrderBefore
    }

    struct Relation: Codable, Equatable, Sendable {
        public var kind: RelationKind
        public var sourceBlockID: String
        public var targetBlockID: String

        public init(kind: RelationKind, sourceBlockID: String, targetBlockID: String) {
            self.kind = kind
            self.sourceBlockID = sourceBlockID
            self.targetBlockID = targetBlockID
        }
    }

    enum Geometry {
        /// Converts an unrotated PDF rectangle (bottom-left origin, +y upward)
        /// to the canonical IR coordinate space (top-left origin, +y downward).
        public static func topLeftRect(fromPDFRect rect: PDFRect, pageHeight: Double) -> PDFRect {
            PDFRect(
                x: rect.origin.x,
                y: pageHeight - rect.origin.y - rect.size.height,
                width: rect.size.width,
                height: rect.size.height
            )
        }

        /// Inverse of `topLeftRect(fromPDFRect:pageHeight:)`.
        public static func pdfRect(fromTopLeftRect rect: PDFRect, pageHeight: Double) -> PDFRect {
            PDFRect(
                x: rect.origin.x,
                y: pageHeight - rect.origin.y - rect.size.height,
                width: rect.size.width,
                height: rect.size.height
            )
        }

        /// Converts an axis-aligned rectangle from the PDF crop-box coordinate
        /// system into the visible, rotated page coordinate system used by IR.
        public static func topLeftRect(
            fromPDFRect rect: PDFRect,
            cropBox: PDFRect,
            rotation: Int
        ) -> PDFRect {
            let normalizedRotation = ((rotation % 360) + 360) % 360
            let x = rect.origin.x - cropBox.origin.x
            let y = rect.origin.y - cropBox.origin.y
            let width = rect.size.width
            let height = rect.size.height
            let pageWidth = cropBox.size.width
            let pageHeight = cropBox.size.height

            switch normalizedRotation {
            case 90:
                return PDFRect(x: y, y: x, width: height, height: width)
            case 180:
                return PDFRect(
                    x: pageWidth - x - width,
                    y: y,
                    width: width,
                    height: height
                )
            case 270:
                return PDFRect(
                    x: pageHeight - y - height,
                    y: pageWidth - x - width,
                    width: height,
                    height: width
                )
            default:
                return PDFRect(
                    x: x,
                    y: pageHeight - y - height,
                    width: width,
                    height: height
                )
            }
        }

        public static func visiblePageSize(cropBox: PDFRect, rotation: Int) -> PDFSize {
            let normalizedRotation = ((rotation % 360) + 360) % 360
            if normalizedRotation == 90 || normalizedRotation == 270 {
                return PDFSize(width: cropBox.size.height, height: cropBox.size.width)
            }
            return cropBox.size
        }
    }
}

public enum DocumentIRValidationError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case duplicateOrInvalidPageIndex(Int)
    case invalidPageSize(Int)
    case invalidPageRotation(Int, Int)
    case duplicateOrEmptyBlockID(String)
    case duplicateOrEmptyLineID(String)
    case duplicateOrEmptyWordID(blockID: String, wordID: String)
    case invalidGeometry(page: Int, ownerID: String)
    case invalidConfidence(ownerID: String)
    case missingReadingOrderBlock(page: Int, blockID: String)
    case duplicateReadingOrderBlock(page: Int, blockID: String)
    case incompatiblePayload(blockID: String, kind: DocumentIR.BlockKind)
    case invalidTable(blockID: String)
    case invalidFigureCaptionReference(figureBlockID: String, captionBlockID: String)
    case missingRelationEndpoint(String)
}

extension DocumentIRValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            "DocumentIR schema version không được hỗ trợ: \(version)."
        case let .duplicateOrInvalidPageIndex(index):
            "Page index âm hoặc bị trùng: \(index)."
        case let .invalidPageSize(index):
            "Kích thước trang \(index) không hợp lệ."
        case let .invalidPageRotation(index, rotation):
            "Góc xoay trang \(index) không hợp lệ: \(rotation)."
        case let .duplicateOrEmptyBlockID(id):
            "Block ID rỗng hoặc bị trùng: \(id)."
        case let .duplicateOrEmptyLineID(id):
            "Line ID rỗng hoặc bị trùng: \(id)."
        case let .duplicateOrEmptyWordID(blockID, wordID):
            "Word ID rỗng hoặc bị trùng trong block \(blockID): \(wordID)."
        case let .invalidGeometry(page, ownerID):
            "Geometry của \(ownerID) nằm ngoài trang \(page)."
        case let .invalidConfidence(ownerID):
            "Confidence của \(ownerID) phải nằm trong khoảng 0...1."
        case let .missingReadingOrderBlock(page, blockID):
            "Reading order trang \(page) tham chiếu block không tồn tại: \(blockID)."
        case let .duplicateReadingOrderBlock(page, blockID):
            "Reading order trang \(page) chứa block trùng: \(blockID)."
        case let .incompatiblePayload(blockID, kind):
            "Payload của block \(blockID) không khớp loại \(kind.rawValue)."
        case let .invalidTable(blockID):
            "Cấu trúc bảng của block \(blockID) không hợp lệ."
        case let .invalidFigureCaptionReference(figureBlockID, captionBlockID):
            "Figure \(figureBlockID) tham chiếu caption không hợp lệ: \(captionBlockID)."
        case let .missingRelationEndpoint(blockID):
            "Quan hệ semantic tham chiếu block không tồn tại: \(blockID)."
        }
    }
}

public enum DocumentIRCodec {
    public static func decodeAndValidate(_ data: Data) throws -> DocumentIR {
        let document = try JSONDecoder().decode(DocumentIR.self, from: data)
        try document.validate()
        return document
    }

    public static func encode(_ document: DocumentIR, prettyPrinted: Bool = false) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(document)
    }
}

private extension DocumentIR {
    static func validate(_ confidence: Double?, ownerID: String) throws {
        guard let confidence else { return }
        guard confidence.isFinite, (0...1).contains(confidence) else {
            throw DocumentIRValidationError.invalidConfidence(ownerID: ownerID)
        }
    }

    static func validate(_ bounds: PDFRect, pageIndex: Int, pageSize: PDFSize, ownerID: String) throws {
        let values = [
            bounds.origin.x,
            bounds.origin.y,
            bounds.size.width,
            bounds.size.height
        ]
        let maxX = bounds.origin.x + bounds.size.width
        let maxY = bounds.origin.y + bounds.size.height
        guard values.allSatisfy(\.isFinite), !bounds.isEmpty,
              bounds.origin.x >= 0, bounds.origin.y >= 0,
              maxX <= pageSize.width, maxY <= pageSize.height else {
            throw DocumentIRValidationError.invalidGeometry(page: pageIndex, ownerID: ownerID)
        }
    }
}
