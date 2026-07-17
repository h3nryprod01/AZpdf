import Foundation
import XCTest
@testable import AZpdf
import AZpdfCore

@MainActor
final class PluginRegistryTests: XCTestCase {
    func testOnlyCompatibleLocalManifestsAreLoaded() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "azpdf-plugins-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try manifest(id: "org.example.local", runsLocally: true, protocolVersion: 1)
            .write(to: directory.appending(path: "local.json"))
        try manifest(id: "org.example.remote", runsLocally: false, protocolVersion: 1)
            .write(to: directory.appending(path: "remote.json"))
        try manifest(id: "org.example.future", runsLocally: true, protocolVersion: 2)
            .write(to: directory.appending(path: "future.json"))

        let outside = FileManager.default.temporaryDirectory.appending(path: "azpdf-plugin-outside-\(UUID().uuidString)")
        try Data().write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(
            at: directory.appending(path: "escaped-executable"),
            withDestinationURL: outside
        )
        try manifest(id: "org.example.escape", runsLocally: true, protocolVersion: 1, executable: "./escaped-executable")
            .write(to: directory.appending(path: "escape.json"))

        let registry = PluginRegistry(directory: directory)

        XCTAssertEqual(registry.plugins.map(\.id), ["org.example.local"])
    }

    private func manifest(
        id: String,
        runsLocally: Bool,
        protocolVersion: Int,
        executable: String = "./plugin"
    ) throws -> Data {
        try JSONEncoder().encode(PluginManifest(
            id: id,
            name: id,
            version: "0.1.0",
            protocolVersion: protocolVersion,
            capabilities: [.ocr],
            executable: executable,
            runsLocally: runsLocally
        ))
    }
}
