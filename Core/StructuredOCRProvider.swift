import Foundation

public enum StructuredOCRFeature: String, Codable, CaseIterable, Sendable {
    case text
    case wordGeometry
    case styles
    case readingOrder
    case tables
    case formulas
    case figures
    case figureAltText
}

public enum StructuredOCRExecutionMode: String, Codable, CaseIterable, Sendable {
    case embeddedCPU
    case embeddedGPU
    case localProcessCPU
    case localProcessGPU
}

/// Capability handshake returned by a local structured-OCR provider. Remote
/// endpoints are deliberately not represented in the v1 contract.
public struct StructuredOCRProviderCapabilities: Codable, Equatable, Sendable {
    public static let currentProtocolVersion = 1

    public var protocolVersion: Int
    public var providerID: String
    public var displayName: String
    public var providerVersion: String
    public var modelID: String
    public var modelVersion: String?
    public var modelLicenseSPDX: String
    public var executionMode: StructuredOCRExecutionMode
    public var features: [StructuredOCRFeature]
    public var supportedLanguages: [String]
    public var minimumVRAMMiB: Int?
    public var maximumPagesPerRequest: Int?

    public init(
        protocolVersion: Int = Self.currentProtocolVersion,
        providerID: String,
        displayName: String,
        providerVersion: String,
        modelID: String,
        modelVersion: String? = nil,
        modelLicenseSPDX: String,
        executionMode: StructuredOCRExecutionMode,
        features: [StructuredOCRFeature],
        supportedLanguages: [String],
        minimumVRAMMiB: Int? = nil,
        maximumPagesPerRequest: Int? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.providerID = providerID
        self.displayName = displayName
        self.providerVersion = providerVersion
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.modelLicenseSPDX = modelLicenseSPDX
        self.executionMode = executionMode
        self.features = features
        self.supportedLanguages = supportedLanguages
        self.minimumVRAMMiB = minimumVRAMMiB
        self.maximumPagesPerRequest = maximumPagesPerRequest
    }

    public func validate() throws {
        guard protocolVersion == Self.currentProtocolVersion else {
            throw StructuredOCRContractError.unsupportedProtocolVersion(protocolVersion)
        }
        for (field, value) in [
            ("providerID", providerID),
            ("displayName", displayName),
            ("providerVersion", providerVersion),
            ("modelID", modelID),
            ("modelLicenseSPDX", modelLicenseSPDX)
        ] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw StructuredOCRContractError.emptyCapabilityField(field)
        }
        guard Set(features).count == features.count, features.contains(.text) else {
            throw StructuredOCRContractError.invalidFeatures
        }
        guard Set(supportedLanguages).count == supportedLanguages.count,
              supportedLanguages.allSatisfy(Self.isLanguageTag) else {
            throw StructuredOCRContractError.invalidLanguages
        }
        if let minimumVRAMMiB, minimumVRAMMiB < 0 {
            throw StructuredOCRContractError.invalidResourceLimit("minimumVRAMMiB")
        }
        if let maximumPagesPerRequest, maximumPagesPerRequest <= 0 {
            throw StructuredOCRContractError.invalidResourceLimit("maximumPagesPerRequest")
        }
    }

    public func supports(_ request: StructuredOCRRequest) -> Bool {
        guard (try? validate()) != nil, (try? request.validate()) != nil else { return false }
        let availableFeatures = Set(features)
        guard request.requiredFeatures.allSatisfy(availableFeatures.contains) else { return false }
        if !supportedLanguages.isEmpty {
            let availableLanguages = Set(supportedLanguages)
            guard request.languages.allSatisfy(availableLanguages.contains) else { return false }
        }
        if let maximumPagesPerRequest, let pageIndexes = request.pageIndexes,
           pageIndexes.count > maximumPagesPerRequest {
            return false
        }
        return true
    }

    fileprivate static func isLanguageTag(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 35 else { return false }
        let segments = value.split(separator: "-", omittingEmptySubsequences: false)
        guard !segments.isEmpty else { return false }
        return segments.allSatisfy { segment in
            !segment.isEmpty && segment.count <= 8 && segment.allSatisfy {
                $0.isASCII && ($0.isLetter || $0.isNumber)
            }
        }
    }
}

public struct StructuredOCRRequest: Codable, Equatable, Sendable {
    public var pageIndexes: [Int]?
    public var languages: [String]
    public var requiredFeatures: [StructuredOCRFeature]
    public var rasterDPI: Int
    public var processPagesWithExistingText: Bool

    public init(
        pageIndexes: [Int]? = nil,
        languages: [String] = ["en"],
        requiredFeatures: [StructuredOCRFeature] = [.text, .wordGeometry],
        rasterDPI: Int = 300,
        processPagesWithExistingText: Bool = false
    ) {
        self.pageIndexes = pageIndexes
        self.languages = languages
        self.requiredFeatures = requiredFeatures
        self.rasterDPI = rasterDPI
        self.processPagesWithExistingText = processPagesWithExistingText
    }

    public func validate() throws {
        if let pageIndexes {
            guard !pageIndexes.isEmpty,
                  pageIndexes.allSatisfy({ $0 >= 0 }),
                  Set(pageIndexes).count == pageIndexes.count else {
                throw StructuredOCRContractError.invalidPageIndexes
            }
        }
        guard !languages.isEmpty,
              Set(languages).count == languages.count,
              languages.allSatisfy(StructuredOCRProviderCapabilities.isLanguageTag) else {
            throw StructuredOCRContractError.invalidLanguages
        }
        guard !requiredFeatures.isEmpty,
              Set(requiredFeatures).count == requiredFeatures.count,
              requiredFeatures.contains(.text) else {
            throw StructuredOCRContractError.invalidFeatures
        }
        guard (72...600).contains(rasterDPI) else {
            throw StructuredOCRContractError.invalidRasterDPI(rasterDPI)
        }
    }
}

public enum StructuredOCRContractError: Error, Equatable, Sendable {
    case unsupportedProtocolVersion(Int)
    case emptyCapabilityField(String)
    case invalidFeatures
    case invalidLanguages
    case invalidResourceLimit(String)
    case invalidPageIndexes
    case invalidRasterDPI(Int)
}

extension StructuredOCRContractError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unsupportedProtocolVersion(version):
            "Structured OCR protocol version không được hỗ trợ: \(version)."
        case let .emptyCapabilityField(field):
            "Structured OCR capability thiếu trường \(field)."
        case .invalidFeatures:
            "Danh sách structured OCR feature không hợp lệ hoặc thiếu text."
        case .invalidLanguages:
            "Danh sách ngôn ngữ phải chứa BCP 47 tag không trùng nhau."
        case let .invalidResourceLimit(field):
            "Giới hạn tài nguyên \(field) không hợp lệ."
        case .invalidPageIndexes:
            "Danh sách trang OCR phải không âm, không rỗng và không trùng."
        case let .invalidRasterDPI(dpi):
            "Structured OCR raster DPI phải trong khoảng 72...600, nhận \(dpi)."
        }
    }
}
