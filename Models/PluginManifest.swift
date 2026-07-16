import Foundation

struct PluginManifest: Codable, Identifiable, Equatable {
    enum Capability: String, Codable, CaseIterable {
        case ocr
        case translate
        case summarize
    }

    let id: String
    let name: String
    let version: String
    let protocolVersion: Int
    let capabilities: [Capability]
    let executable: String
    let runsLocally: Bool
}
