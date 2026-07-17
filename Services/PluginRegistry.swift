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
            .filter(isInsidePluginsDirectory)
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(PluginManifest.self, from: $0) }
            .filter(DocumentPrivacyPolicy.accepts)
            .filter { isSafeExecutable($0.executable) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Discovery is intentionally stricter than the portable manifest validator:
    /// both a manifest symlink and a future executable symlink must stay inside
    /// AZpdf's plugin directory. This is not an execution sandbox; the host still
    /// does not launch plugins until an XPC boundary exists.
    private func isInsidePluginsDirectory(_ url: URL) -> Bool {
        isWithinPluginsDirectory(url.resolvingSymlinksInPath())
    }

    private func isSafeExecutable(_ path: String) -> Bool {
        isWithinPluginsDirectory(
            pluginsDirectory
                .appending(path: path)
                .resolvingSymlinksInPath()
        )
    }

    private func isWithinPluginsDirectory(_ url: URL) -> Bool {
        let root = pluginsDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let candidate = url.standardizedFileURL.path
        return candidate == root || candidate.hasPrefix(root + "/")
    }
}
