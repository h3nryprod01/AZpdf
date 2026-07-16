import Foundation

public enum PluginManifestValidationError: Error, Equatable, Sendable {
    case invalidIdentifier
    case unsupportedProtocol
    case remoteExecutionNotAllowed
    case noCapabilities
    case unsafeExecutablePath
}

public enum PluginManifestValidator {
    public static func validate(_ manifest: PluginManifest) throws {
        guard manifest.id.range(of: "^[A-Za-z0-9]+([.-][A-Za-z0-9]+)+$", options: .regularExpression) != nil else {
            throw PluginManifestValidationError.invalidIdentifier
        }
        guard manifest.protocolVersion == DocumentPrivacyPolicy.supportedPluginProtocolVersion else {
            throw PluginManifestValidationError.unsupportedProtocol
        }
        guard manifest.runsLocally else {
            throw PluginManifestValidationError.remoteExecutionNotAllowed
        }
        guard !manifest.capabilities.isEmpty else {
            throw PluginManifestValidationError.noCapabilities
        }
        guard !manifest.executable.hasPrefix("/"),
              !manifest.executable.split(separator: "/").contains("..") else {
            throw PluginManifestValidationError.unsafeExecutablePath
        }
    }
}
