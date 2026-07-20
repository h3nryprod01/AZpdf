import Foundation

/// Flatpak production runner for structured OCR providers packaged below
/// `/app`. It creates a tighter child sandbox through `flatpak-spawn`, keeps
/// networking disabled and exposes only staged request files plus one writable
/// output directory. It never invokes `flatpak-spawn --host`.
public struct FlatpakSpawnStructuredOCRRunner: StructuredOCRProcessRunning {
    public let networkIsolation: StructuredOCRNetworkIsolation = .operatingSystemSandbox
    public let flatpakSpawnURL: URL
    public let appRootURL: URL
    public let instanceSandboxURL: URL?
    public let flatpakID: String?
    public let maximumStagedOutputBytes: Int

    private let launcher: any StructuredOCRProcessRunning

    public init(
        flatpakSpawnURL: URL = URL(fileURLWithPath: "/usr/bin/flatpak-spawn"),
        appRootURL: URL = URL(fileURLWithPath: "/app", isDirectory: true),
        instanceSandboxURL: URL? = nil,
        flatpakID: String? = ProcessInfo.processInfo.environment["FLATPAK_ID"],
        maximumStagedOutputBytes: Int = 256 * 1_024 * 1_024,
        launcher: any StructuredOCRProcessRunning = SubprocessStructuredOCRRunner()
    ) {
        self.flatpakSpawnURL = flatpakSpawnURL
        self.appRootURL = appRootURL.standardizedFileURL
        self.instanceSandboxURL = instanceSandboxURL?.standardizedFileURL
        self.flatpakID = flatpakID
        self.maximumStagedOutputBytes = max(1, maximumStagedOutputBytes)
        self.launcher = launcher
    }

    public func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        #if os(Linux)
        guard FileManager.default.isExecutableFile(atPath: flatpakSpawnURL.path),
              let flatpakID,
              Self.isValidFlatpakID(flatpakID) else {
            throw StructuredOCRProcessError.sandboxUnavailable
        }

        let prepared = try prepareInvocation(executable: executable, arguments: arguments)
        defer { prepared.cleanup() }

        let result = try launcher.run(executable: flatpakSpawnURL, arguments: prepared.arguments)
        if result.status != 0, isFlatpakBootstrapFailure(result.standardError) {
            throw StructuredOCRProcessError.sandboxUnavailable
        }
        if result.status == 0 {
            try prepared.copyOutput(maximumBytes: maximumStagedOutputBytes)
        }
        return result
        #else
        throw StructuredOCRProcessError.sandboxUnavailable
        #endif
    }

    func prepareInvocation(
        executable: URL,
        arguments: [String],
        token: String = UUID().uuidString.lowercased()
    ) throws -> FlatpakStructuredOCRInvocation {
        let fileManager = FileManager.default
        let providerExecutable = executable.resolvingSymlinksInPath().standardizedFileURL
        let appRoot = appRootURL.resolvingSymlinksInPath().standardizedFileURL
        guard fileManager.isExecutableFile(atPath: providerExecutable.path),
              Self.isDescendant(providerExecutable, of: appRoot) else {
            throw StructuredOCRProcessError.runtimeUnavailable
        }
        guard Self.isSafeStageName(token) else {
            throw StructuredOCRProcessError.invalidInvocation
        }

        var spawnArguments = [
            "--sandbox",
            "--no-network",
            "--clear-env",
            "--watch-bus"
        ]
        var providerArguments = arguments
        var cleanupURLs: [URL] = []
        var stagedOutputURL: URL?
        var destinationOutputURL: URL?

        if arguments.first == "recognize" {
            guard let input = Self.argumentValue(after: "--input", in: arguments),
                  let request = Self.argumentValue(after: "--request", in: arguments),
                  let output = Self.argumentValue(after: "--output", in: arguments) else {
                throw StructuredOCRProcessError.invalidInvocation
            }

            let inputURL = URL(fileURLWithPath: input).resolvingSymlinksInPath().standardizedFileURL
            let requestURL = URL(fileURLWithPath: request).resolvingSymlinksInPath().standardizedFileURL
            let outputURL = URL(fileURLWithPath: output).standardizedFileURL
            guard Self.isRegularFile(inputURL), Self.isRegularFile(requestURL),
                  Self.isDirectory(outputURL.deletingLastPathComponent()) else {
                throw StructuredOCRProcessError.invalidInvocation
            }

            let sandboxDirectory = try resolvedInstanceSandboxDirectory(flatpakID: flatpakID)
            try fileManager.createDirectory(at: sandboxDirectory, withIntermediateDirectories: true)
            #if !os(Windows)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sandboxDirectory.path)
            #endif

            let inputName = "azpdf-input-\(token).pdf"
            let requestName = "azpdf-request-\(token).json"
            let workName = "azpdf-work-\(token)"
            let stagedInput = sandboxDirectory.appendingPathComponent(inputName)
            let stagedRequest = sandboxDirectory.appendingPathComponent(requestName)
            let stagedWork = sandboxDirectory.appendingPathComponent(workName, isDirectory: true)

            guard !fileManager.fileExists(atPath: stagedInput.path),
                  !fileManager.fileExists(atPath: stagedRequest.path),
                  !fileManager.fileExists(atPath: stagedWork.path) else {
                throw StructuredOCRProcessError.invalidInvocation
            }

            do {
                try fileManager.copyItem(at: inputURL, to: stagedInput)
                cleanupURLs.append(stagedInput)
                try fileManager.copyItem(at: requestURL, to: stagedRequest)
                cleanupURLs.append(stagedRequest)
                try fileManager.createDirectory(at: stagedWork, withIntermediateDirectories: false)
                cleanupURLs.append(stagedWork)
                #if !os(Windows)
                try fileManager.setAttributes([.posixPermissions: 0o400], ofItemAtPath: stagedInput.path)
                try fileManager.setAttributes([.posixPermissions: 0o400], ofItemAtPath: stagedRequest.path)
                try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stagedWork.path)
                #endif
            } catch {
                cleanupURLs.reversed().forEach { try? fileManager.removeItem(at: $0) }
                throw error
            }

            let outputName = "document-ir.json"
            let stagedOutput = stagedWork.appendingPathComponent(outputName)
            spawnArguments.append(contentsOf: [
                "--sandbox-expose-ro=\(inputName)",
                "--sandbox-expose-ro=\(requestName)",
                "--sandbox-expose=\(workName)"
            ])
            Self.replaceArgument(after: "--input", with: stagedInput.path, in: &providerArguments)
            Self.replaceArgument(after: "--request", with: stagedRequest.path, in: &providerArguments)
            Self.replaceArgument(after: "--output", with: stagedOutput.path, in: &providerArguments)
            stagedOutputURL = stagedOutput
            destinationOutputURL = outputURL
        } else if arguments.first != "capabilities" {
            throw StructuredOCRProcessError.invalidInvocation
        }

        spawnArguments.append("--")
        spawnArguments.append(providerExecutable.path)
        spawnArguments.append(contentsOf: providerArguments)
        return FlatpakStructuredOCRInvocation(
            arguments: spawnArguments,
            cleanupURLs: cleanupURLs,
            stagedOutputURL: stagedOutputURL,
            destinationOutputURL: destinationOutputURL
        )
    }

    private func resolvedInstanceSandboxDirectory(flatpakID: String?) throws -> URL {
        if let instanceSandboxURL {
            return instanceSandboxURL
        }
        guard let flatpakID, Self.isValidFlatpakID(flatpakID) else {
            throw StructuredOCRProcessError.sandboxUnavailable
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".var/app", isDirectory: true)
            .appendingPathComponent(flatpakID, isDirectory: true)
            .appendingPathComponent("sandbox", isDirectory: true)
    }

    private func isFlatpakBootstrapFailure(_ standardError: Data) -> Bool {
        let message = String(decoding: standardError, as: UTF8.self).lowercased()
        return message.contains("flatpak-spawn:")
            || message.contains("portal call failed")
            || message.contains("org.freedesktop.portal.flatpak")
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func replaceArgument(after flag: String, with value: String, in arguments: inout [String]) {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return }
        arguments[index + 1] = value
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return false }
        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        candidate.path.hasPrefix(root.path.hasSuffix("/") ? root.path : root.path + "/")
    }

    private static func isSafeStageName(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 80 && value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
        }
    }

    private static func isValidFlatpakID(_ value: String) -> Bool {
        guard value.count >= 3, value.count <= 255,
              !value.hasPrefix("."), !value.hasSuffix("."), value.contains(".") else {
            return false
        }
        return value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { segment in
            !segment.isEmpty && segment.count <= 63 && segment.allSatisfy {
                $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-")
            }
        }
    }
}

struct FlatpakStructuredOCRInvocation {
    let arguments: [String]
    let cleanupURLs: [URL]
    let stagedOutputURL: URL?
    let destinationOutputURL: URL?

    func copyOutput(maximumBytes: Int) throws {
        guard let stagedOutputURL, let destinationOutputURL else { return }
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: stagedOutputURL.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0 else {
            throw StructuredOCRProcessError.invalidOutput("Flatpak provider không tạo regular output file.")
        }
        guard size.intValue <= maximumBytes else {
            throw StructuredOCRProcessError.outputTooLarge(size.intValue)
        }
        if fileManager.fileExists(atPath: destinationOutputURL.path) {
            try fileManager.removeItem(at: destinationOutputURL)
        }
        try fileManager.copyItem(at: stagedOutputURL, to: destinationOutputURL)
    }

    func cleanup() {
        let fileManager = FileManager.default
        cleanupURLs.reversed().forEach { try? fileManager.removeItem(at: $0) }
    }
}
