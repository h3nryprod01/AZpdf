import Foundation
import Observation
import AZpdfCore

/// Discovers opt-in local plugins only. It intentionally has no networking API.
@Observable
final class PluginRegistry {
    static let supportedProtocolVersion = DocumentPrivacyPolicy.supportedPluginProtocolVersion
    private(set) var plugins: [PluginManifest] = []
    let pluginsDirectory: URL

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        pluginsDirectory = directory ?? appSupport.appending(path: "AZpdf/Plugins", directoryHint: .isDirectory)
        reload()
    }

    func reload() {
        let manifestURLs = (try? FileManager.default.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        plugins = manifestURLs
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(PluginManifest.self, from: $0) }
            .filter(DocumentPrivacyPolicy.accepts)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
