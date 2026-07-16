import XCTest
@testable import AZpdfCore

final class DocumentPrivacyPolicyTests: XCTestCase {
    func testPolicyAcceptsOnlyCompatibleLocalPlugin() {
        let local = PluginManifest(
            id: "local",
            name: "Local",
            version: "1.0.0",
            protocolVersion: 1,
            capabilities: [.ocr],
            executable: "./local",
            runsLocally: true
        )
        let remote = PluginManifest(
            id: "remote",
            name: "Remote",
            version: "1.0.0",
            protocolVersion: 1,
            capabilities: [.ocr],
            executable: "./remote",
            runsLocally: false
        )

        XCTAssertTrue(DocumentPrivacyPolicy.accepts(local))
        XCTAssertFalse(DocumentPrivacyPolicy.accepts(remote))
        XCTAssertFalse(DocumentPrivacyPolicy.allowsAutomaticNetworkAccess)
    }

    func testDocumentOperationRetainsCrossPlatformIntent() {
        XCTAssertEqual(
            DocumentOperation.movePages(from: [1, 3], destination: 5),
            DocumentOperation.movePages(from: [1, 3], destination: 5)
        )
    }
}
