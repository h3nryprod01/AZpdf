import Foundation

/// Portable plugin metadata. It deliberately contains no network endpoint.
public struct PluginManifest: Codable, Identifiable, Equatable, Sendable {
    public enum Capability: String, Codable, CaseIterable, Sendable {
        case ocr
        case translate
        case summarize
    }

    public let id: String
    public let name: String
    public let version: String
    public let protocolVersion: Int
    public let capabilities: [Capability]
    public let executable: String
    public let runsLocally: Bool

    public init(
        id: String,
        name: String,
        version: String,
        protocolVersion: Int,
        capabilities: [Capability],
        executable: String,
        runsLocally: Bool
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.executable = executable
        self.runsLocally = runsLocally
    }
}
