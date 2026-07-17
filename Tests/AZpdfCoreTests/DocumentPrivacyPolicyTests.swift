import XCTest
@testable import AZpdfCore

final class DocumentPrivacyPolicyTests: XCTestCase {
    func testPolicyAcceptsOnlyCompatibleLocalPlugin() {
        let local = PluginManifest(
            id: "org.example.local",
            name: "Local",
            version: "1.0.0",
            protocolVersion: 1,
            capabilities: [.ocr],
            executable: "./local",
            runsLocally: true
        )
        let remote = PluginManifest(
            id: "org.example.remote",
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

    func testPluginValidatorRejectsPathEscapeAndRemotePlugin() {
        let pathEscape = PluginManifest(
            id: "org.example.escape",
            name: "Escape",
            version: "1.0.0",
            protocolVersion: 1,
            capabilities: [.ocr],
            executable: "../outside",
            runsLocally: true
        )
        let remote = PluginManifest(
            id: "org.example.remote",
            name: "Remote",
            version: "1.0.0",
            protocolVersion: 1,
            capabilities: [.ocr],
            executable: "./local",
            runsLocally: false
        )

        XCTAssertThrowsError(try PluginManifestValidator.validate(pathEscape)) { error in
            XCTAssertEqual(error as? PluginManifestValidationError, .unsafeExecutablePath)
        }
        XCTAssertThrowsError(try PluginManifestValidator.validate(remote)) { error in
            XCTAssertEqual(error as? PluginManifestValidationError, .remoteExecutionNotAllowed)
        }
    }

    func testDocumentGrantIsScopedToPluginCapabilityAndDocument() throws {
        let manifest = PluginManifest(
            id: "org.example.local",
            name: "Local",
            version: "1.0.0",
            protocolVersion: 1,
            capabilities: [.ocr],
            executable: "./local",
            runsLocally: true
        )
        let documentID = UUID()
        let grant = try PluginAccessPolicy.issue(for: manifest, documentScopeID: documentID, capabilities: [.ocr])

        XCTAssertTrue(PluginAccessPolicy.permits(grant, pluginID: manifest.id, documentScopeID: documentID, capability: .ocr))
        XCTAssertFalse(PluginAccessPolicy.permits(grant, pluginID: manifest.id, documentScopeID: UUID(), capability: .ocr))
        XCTAssertFalse(PluginAccessPolicy.permits(grant, pluginID: "org.example.other", documentScopeID: documentID, capability: .ocr))
    }

    func testDocumentGrantRejectsUndeclaredCapability() {
        let manifest = PluginManifest(
            id: "org.example.local",
            name: "Local",
            version: "1.0.0",
            protocolVersion: 1,
            capabilities: [.ocr],
            executable: "./local",
            runsLocally: true
        )
        XCTAssertThrowsError(try PluginAccessPolicy.issue(
            for: manifest,
            documentScopeID: UUID(),
            capabilities: [.summarize]
        )) { error in
            XCTAssertEqual(error as? PluginGrantError, .unsupportedCapability)
        }
    }
}
