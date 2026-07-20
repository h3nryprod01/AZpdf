import XCTest
@testable import AZpdfCore

final class StructuredOCRProviderTests: XCTestCase {
    func testProviderSupportsCompatibleLocalRequest() throws {
        let provider = makeProvider()
        let request = StructuredOCRRequest(
            pageIndexes: [0, 2],
            languages: ["vi", "en"],
            requiredFeatures: [.text, .wordGeometry, .tables, .formulas]
        )

        try provider.validate()
        try request.validate()
        XCTAssertTrue(provider.supports(request))
    }

    func testProviderRejectsMissingFeatureLanguageAndPageLimit() {
        let provider = makeProvider()

        XCTAssertFalse(provider.supports(.init(languages: ["ja"])))
        XCTAssertFalse(provider.supports(.init(requiredFeatures: [.text, .figureAltText])))
        XCTAssertFalse(provider.supports(.init(pageIndexes: [0, 1, 2, 3, 4])))
    }

    func testRequestRejectsUnsafeLanguageDuplicatePageAndDPI() {
        XCTAssertThrowsError(try StructuredOCRRequest(languages: ["vi;rm"]).validate()) { error in
            XCTAssertEqual(error as? StructuredOCRContractError, .invalidLanguages)
        }
        XCTAssertThrowsError(try StructuredOCRRequest(pageIndexes: [1, 1]).validate()) { error in
            XCTAssertEqual(error as? StructuredOCRContractError, .invalidPageIndexes)
        }
        XCTAssertThrowsError(try StructuredOCRRequest(rasterDPI: 1_200).validate()) { error in
            XCTAssertEqual(error as? StructuredOCRContractError, .invalidRasterDPI(1_200))
        }
    }

    func testCapabilityRoundTripRetainsModelAndLicense() throws {
        let provider = makeProvider()
        let encoded = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(StructuredOCRProviderCapabilities.self, from: encoded)

        XCTAssertEqual(decoded, provider)
        XCTAssertEqual(decoded.modelLicenseSPDX, "Apache-2.0")
        XCTAssertEqual(decoded.executionMode, .localProcessGPU)
    }

    private func makeProvider() -> StructuredOCRProviderCapabilities {
        .init(
            providerID: "org.azpdf.paddleocr-vl",
            displayName: "PaddleOCR-VL",
            providerVersion: "1.0.0",
            modelID: "PaddleOCR-VL-1.6",
            modelVersion: "1.6",
            modelLicenseSPDX: "Apache-2.0",
            executionMode: .localProcessGPU,
            features: [.text, .wordGeometry, .styles, .readingOrder, .tables, .formulas, .figures],
            supportedLanguages: ["vi", "en"],
            minimumVRAMMiB: 8_192,
            maximumPagesPerRequest: 4
        )
    }
}
