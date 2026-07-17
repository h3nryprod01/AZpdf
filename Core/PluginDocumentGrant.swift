import Foundation

/// An in-memory capability grant for one document session. It deliberately has
/// no file URL, bookmark, network endpoint or persistence mechanism: the future
/// XPC host receives only a host-created read-only copy after this grant exists.
public struct PluginDocumentGrant: Equatable, Sendable {
    public let pluginID: String
    public let documentScopeID: UUID
    public let capabilities: Set<PluginManifest.Capability>

    public init(pluginID: String, documentScopeID: UUID, capabilities: Set<PluginManifest.Capability>) {
        self.pluginID = pluginID
        self.documentScopeID = documentScopeID
        self.capabilities = capabilities
    }
}

public enum PluginGrantError: Error, Equatable, Sendable {
    case emptyCapabilities
    case unsupportedCapability
}

public enum PluginAccessPolicy {
    /// Issues a non-persistent grant only when the requested capabilities were
    /// declared by a compatible local plugin manifest.
    public static func issue(
        for manifest: PluginManifest,
        documentScopeID: UUID,
        capabilities: Set<PluginManifest.Capability>
    ) throws -> PluginDocumentGrant {
        guard DocumentPrivacyPolicy.accepts(manifest) else { throw PluginGrantError.unsupportedCapability }
        guard !capabilities.isEmpty else { throw PluginGrantError.emptyCapabilities }
        guard capabilities.isSubset(of: Set(manifest.capabilities)) else {
            throw PluginGrantError.unsupportedCapability
        }
        return PluginDocumentGrant(
            pluginID: manifest.id,
            documentScopeID: documentScopeID,
            capabilities: capabilities
        )
    }

    public static func permits(
        _ grant: PluginDocumentGrant,
        pluginID: String,
        documentScopeID: UUID,
        capability: PluginManifest.Capability
    ) -> Bool {
        grant.pluginID == pluginID
            && grant.documentScopeID == documentScopeID
            && grant.capabilities.contains(capability)
    }
}
