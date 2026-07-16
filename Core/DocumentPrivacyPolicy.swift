import Foundation

/// Invariants that every platform adapter and future plugin host must preserve.
public enum DocumentPrivacyPolicy {
    public static let allowsAutomaticNetworkAccess = false
    public static let supportedPluginProtocolVersion = 1

    public static func accepts(_ manifest: PluginManifest) -> Bool {
        (try? PluginManifestValidator.validate(manifest)) != nil
    }
}
