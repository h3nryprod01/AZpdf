import Foundation

public struct PDFPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PDFSize: Codable, Equatable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct PDFRect: Codable, Equatable, Hashable, Sendable {
    public var origin: PDFPoint
    public var size: PDFSize

    public init(x: Double, y: Double, width: Double, height: Double) {
        origin = PDFPoint(x: x, y: y)
        size = PDFSize(width: width, height: height)
    }

    public var isEmpty: Bool { size.width <= 0 || size.height <= 0 }
}

public struct PDFColor: Codable, Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct PDFDocumentMetadata: Codable, Equatable, Sendable {
    public var title: String?
    public var author: String?
    public var subject: String?
    public var keywords: [String]
    public var creator: String?
    public var producer: String?
    public var language: String?

    public init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: [String] = [],
        creator: String? = nil,
        producer: String? = nil,
        language: String? = nil
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
        self.creator = creator
        self.producer = producer
        self.language = language
    }
}

public struct PDFPageDescriptor: Codable, Equatable, Sendable {
    public let index: Int
    public var label: String?
    public var mediaBox: PDFRect
    public var cropBox: PDFRect
    public var rotation: Int

    public init(index: Int, label: String? = nil, mediaBox: PDFRect, cropBox: PDFRect, rotation: Int = 0) {
        self.index = index
        self.label = label
        self.mediaBox = mediaBox
        self.cropBox = cropBox
        self.rotation = ((rotation % 360) + 360) % 360
    }
}

public enum PDFAnnotationKind: String, Codable, CaseIterable, Sendable {
    case note
    case highlight
    case freeText
    case signature
    case image
    case ink
    case link
    case redaction
    case widget
    case unknown
}

public enum PDFTextAlignment: String, Codable, CaseIterable, Sendable {
    case left
    case center
    case right
}

public struct PDFTextStyle: Codable, Equatable, Sendable {
    public var fontName: String
    public var fontSize: Double
    public var color: PDFColor
    public var alignment: PDFTextAlignment
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool

    public init(
        fontName: String = "Helv",
        fontSize: Double = 14,
        color: PDFColor = .init(red: 0, green: 0, blue: 0),
        alignment: PDFTextAlignment = .left,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false
    ) {
        self.fontName = fontName
        self.fontSize = max(1, fontSize)
        self.color = color
        self.alignment = alignment
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
    }
}

public enum PDFImageFormat: String, Codable, CaseIterable, Sendable {
    case png
    case jpeg
}

public struct PDFAnnotationDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var kind: PDFAnnotationKind
    public var pageIndex: Int
    public var bounds: PDFRect
    public var contents: String?
    public var color: PDFColor?
    public var opacity: Double
    public var coordinateSpace: PDFCoordinateSpace
    public var textStyle: PDFTextStyle?

    public init(
        id: String,
        kind: PDFAnnotationKind,
        pageIndex: Int,
        bounds: PDFRect,
        contents: String? = nil,
        color: PDFColor? = nil,
        opacity: Double = 1,
        coordinateSpace: PDFCoordinateSpace = .pdfBottomLeft,
        textStyle: PDFTextStyle? = nil
    ) {
        self.id = id
        self.kind = kind
        self.pageIndex = pageIndex
        self.bounds = bounds
        self.contents = contents
        self.color = color
        self.opacity = opacity
        self.coordinateSpace = coordinateSpace
        self.textStyle = textStyle
    }
}

public struct PDFSearchMatch: Codable, Equatable, Sendable {
    public let pageIndex: Int
    public let text: String
    public let bounds: [PDFRect]

    public init(pageIndex: Int, text: String, bounds: [PDFRect] = []) {
        self.pageIndex = pageIndex
        self.text = text
        self.bounds = bounds
    }
}

public enum PDFCoordinateSpace: String, Codable, Sendable {
    case pdfBottomLeft
    case pageTopLeft
}

public struct PDFTextLine: Codable, Equatable, Sendable {
    public var bounds: PDFRect
    public var text: String
    public var fontName: String?
    public var fontFamily: String?
    public var fontSize: Double?
    public var writingMode: Int

    public init(
        bounds: PDFRect,
        text: String,
        fontName: String? = nil,
        fontFamily: String? = nil,
        fontSize: Double? = nil,
        writingMode: Int = 0
    ) {
        self.bounds = bounds
        self.text = text
        self.fontName = fontName
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.writingMode = writingMode
    }
}

public enum PDFTextBlockKind: String, Codable, Sendable {
    case text
    case image
    case unknown
}

public struct PDFTextBlock: Codable, Equatable, Sendable {
    public var kind: PDFTextBlockKind
    public var bounds: PDFRect
    public var lines: [PDFTextLine]

    public init(kind: PDFTextBlockKind, bounds: PDFRect, lines: [PDFTextLine] = []) {
        self.kind = kind
        self.bounds = bounds
        self.lines = lines
    }
}

public struct PDFPageTextLayout: Codable, Equatable, Sendable {
    public var pageIndex: Int
    public var coordinateSpace: PDFCoordinateSpace
    public var blocks: [PDFTextBlock]

    public init(
        pageIndex: Int,
        coordinateSpace: PDFCoordinateSpace,
        blocks: [PDFTextBlock]
    ) {
        self.pageIndex = pageIndex
        self.coordinateSpace = coordinateSpace
        self.blocks = blocks
    }
}

public enum PDFOCRFeature: String, Codable, CaseIterable, Sendable {
    case searchablePDF
    case visualLayoutPreservation
    case boundingBoxes
    case readingOrder
    case tables
    case formulas
    case images
    case structuredOutput
}

public struct PDFOCRCapabilities: Codable, Equatable, Sendable {
    public var provider: String
    public var version: String
    public var executable: String
    public var features: [PDFOCRFeature]

    public init(
        provider: String,
        version: String,
        executable: String,
        features: [PDFOCRFeature]
    ) {
        self.provider = provider
        self.version = version
        self.executable = executable
        self.features = features
    }
}

public struct PDFOCRRequest: Codable, Equatable, Sendable {
    public var language: String
    public var skipText: Bool
    public var deskew: Bool
    public var rotatePages: Bool

    public init(
        language: String = "eng",
        skipText: Bool = true,
        deskew: Bool = false,
        rotatePages: Bool = false
    ) {
        self.language = language
        self.skipText = skipText
        self.deskew = deskew
        self.rotatePages = rotatePages
    }
}

public struct PDFOCRResult: Codable, Equatable, Sendable {
    public var provider: String
    public var version: String
    public var language: String
    public var output: URL
    public var bytes: Int
    public var features: [PDFOCRFeature]

    public init(
        provider: String,
        version: String,
        language: String,
        output: URL,
        bytes: Int,
        features: [PDFOCRFeature]
    ) {
        self.provider = provider
        self.version = version
        self.language = language
        self.output = output
        self.bytes = bytes
        self.features = features
    }
}

public enum PDFSignatureProfile: String, Codable, CaseIterable, Sendable {
    case baselineB
    case baselineLT
    case baselineLTA

    public var requiresTimestamp: Bool { self != .baselineB }
}

public enum PDFSignatureIntegrity: String, Codable, Sendable {
    case valid
    case invalid
    case unsigned
    case unknown
}

public enum PDFCertificateTrust: String, Codable, Sendable {
    case trusted
    case untrusted
    case unknown
}

public struct PDFSignatureVerification: Codable, Equatable, Sendable {
    public var integrity: PDFSignatureIntegrity
    public var certificateTrust: PDFCertificateTrust
    public var signerName: String?
    public var details: String
    public var hasTimestamp: Bool
    public var hasValidationInfo: Bool

    public init(
        integrity: PDFSignatureIntegrity,
        certificateTrust: PDFCertificateTrust,
        signerName: String? = nil,
        details: String,
        hasTimestamp: Bool = false,
        hasValidationInfo: Bool = false
    ) {
        self.integrity = integrity
        self.certificateTrust = certificateTrust
        self.signerName = signerName
        self.details = details
        self.hasTimestamp = hasTimestamp
        self.hasValidationInfo = hasValidationInfo
    }

    public var isCryptographicallyValid: Bool { integrity == .valid }
}

public struct PDFSignatureCapabilities: Codable, Equatable, Sendable {
    public var provider: String
    public var version: String
    public var executable: String
    public var profiles: [PDFSignatureProfile]

    public init(
        provider: String,
        version: String,
        executable: String,
        profiles: [PDFSignatureProfile]
    ) {
        self.provider = provider
        self.version = version
        self.executable = executable
        self.profiles = profiles
    }
}

public struct PDFSignatureRequest: Codable, Equatable, Sendable {
    public var profile: PDFSignatureProfile
    public var fieldSpec: String
    public var timestampURL: String?

    public init(
        profile: PDFSignatureProfile = .baselineB,
        fieldSpec: String = "1/36,36,260,96/AZpdfSignature",
        timestampURL: String? = nil
    ) {
        self.profile = profile
        self.fieldSpec = fieldSpec
        self.timestampURL = timestampURL
    }
}

public struct PDFSignatureResult: Codable, Equatable, Sendable {
    public var provider: String
    public var version: String
    public var profile: PDFSignatureProfile
    public var output: URL
    public var bytes: Int
    public var verification: PDFSignatureVerification

    public init(
        provider: String,
        version: String,
        profile: PDFSignatureProfile,
        output: URL,
        bytes: Int,
        verification: PDFSignatureVerification
    ) {
        self.provider = provider
        self.version = version
        self.profile = profile
        self.output = output
        self.bytes = bytes
        self.verification = verification
    }
}

public struct PDFOutlineItem: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var pageIndex: Int?
    public var destination: PDFPoint?
    public var isOpen: Bool
    public var children: [PDFOutlineItem]

    public init(
        id: String,
        title: String,
        pageIndex: Int? = nil,
        destination: PDFPoint? = nil,
        isOpen: Bool = false,
        children: [PDFOutlineItem] = []
    ) {
        self.id = id
        self.title = title
        self.pageIndex = pageIndex
        self.destination = destination
        self.isOpen = isOpen
        self.children = children
    }
}

public enum PDFFormFieldKind: String, Codable, Sendable {
    case text
    case checkBox
    case radioButton
    case pushButton
    case choice
    case signature
    case unknown
}

public struct PDFFormFieldDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var name: String?
    public var kind: PDFFormFieldKind
    public var pageIndex: Int
    public var bounds: PDFRect
    public var value: String?
    public var defaultValue: String?
    public var choices: [String]
    public var isReadOnly: Bool
    public var isMultiline: Bool
    public var isPassword: Bool
    public var maximumLength: Int?

    public init(
        id: String,
        name: String? = nil,
        kind: PDFFormFieldKind,
        pageIndex: Int,
        bounds: PDFRect,
        value: String? = nil,
        defaultValue: String? = nil,
        choices: [String] = [],
        isReadOnly: Bool = false,
        isMultiline: Bool = false,
        isPassword: Bool = false,
        maximumLength: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.pageIndex = pageIndex
        self.bounds = bounds
        self.value = value
        self.defaultValue = defaultValue
        self.choices = choices
        self.isReadOnly = isReadOnly
        self.isMultiline = isMultiline
        self.isPassword = isPassword
        self.maximumLength = maximumLength
    }
}

public struct PDFDocumentSecurity: Codable, Equatable, Sendable {
    public var isEncrypted: Bool
    public var isLocked: Bool
    public var allowsPrinting: Bool
    public var allowsCopying: Bool
    public var allowsDocumentChanges: Bool
    public var allowsDocumentAssembly: Bool
    public var allowsContentAccessibility: Bool
    public var allowsCommenting: Bool
    public var allowsFormFieldEntry: Bool

    public init(
        isEncrypted: Bool,
        isLocked: Bool,
        allowsPrinting: Bool,
        allowsCopying: Bool,
        allowsDocumentChanges: Bool,
        allowsDocumentAssembly: Bool,
        allowsContentAccessibility: Bool,
        allowsCommenting: Bool,
        allowsFormFieldEntry: Bool
    ) {
        self.isEncrypted = isEncrypted
        self.isLocked = isLocked
        self.allowsPrinting = allowsPrinting
        self.allowsCopying = allowsCopying
        self.allowsDocumentChanges = allowsDocumentChanges
        self.allowsDocumentAssembly = allowsDocumentAssembly
        self.allowsContentAccessibility = allowsContentAccessibility
        self.allowsCommenting = allowsCommenting
        self.allowsFormFieldEntry = allowsFormFieldEntry
    }
}

public struct PDFEmbeddedFileDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var filename: String
    public var mimeType: String?
    public var size: Int?
    public var description: String?

    public init(
        id: String,
        filename: String,
        mimeType: String? = nil,
        size: Int? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.description = description
    }
}

public enum PDFRasterFormat: String, Codable, Sendable {
    case rgba8
    case png
}

public struct PDFRenderRequest: Codable, Equatable, Sendable {
    public var pageIndex: Int
    public var scale: Double
    public var background: PDFColor

    public init(pageIndex: Int, scale: Double = 1, background: PDFColor = .init(red: 1, green: 1, blue: 1)) {
        self.pageIndex = pageIndex
        self.scale = scale
        self.background = background
    }
}

public struct PDFRenderedPage: Equatable, Sendable {
    public let size: PDFSize
    public let format: PDFRasterFormat
    public let data: Data
    public let pageBox: PDFRect
    public let rotation: Int

    public init(
        size: PDFSize,
        format: PDFRasterFormat,
        data: Data,
        pageBox: PDFRect? = nil,
        rotation: Int = 0
    ) {
        self.size = size
        self.format = format
        self.data = data
        self.pageBox = pageBox ?? PDFRect(x: 0, y: 0, width: size.width, height: size.height)
        self.rotation = ((rotation % 360) + 360) % 360
    }
}

public struct PDFEngineCapabilities: OptionSet, Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public static let open = Self(rawValue: 1 << 0)
    public static let save = Self(rawValue: 1 << 1)
    public static let render = Self(rawValue: 1 << 2)
    public static let extractText = Self(rawValue: 1 << 3)
    public static let search = Self(rawValue: 1 << 4)
    public static let metadata = Self(rawValue: 1 << 5)
    public static let annotations = Self(rawValue: 1 << 6)
    public static let forms = Self(rawValue: 1 << 7)
    public static let pageEditing = Self(rawValue: 1 << 8)
    public static let redaction = Self(rawValue: 1 << 9)
    public static let encryption = Self(rawValue: 1 << 10)
    public static let digitalSignatures = Self(rawValue: 1 << 11)
    public static let outline = Self(rawValue: 1 << 12)
    public static let embeddedFiles = Self(rawValue: 1 << 13)
    public static let structuredText = Self(rawValue: 1 << 14)
}
