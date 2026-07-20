import Foundation

/// Linux production runner. The provider sees only its packaged directory,
/// selected system runtime paths, the input file and a dedicated writable work
/// directory. Network, PID, IPC and UTS namespaces are isolated.
public struct BubblewrapStructuredOCRRunner: StructuredOCRProcessRunning {
    public let networkIsolation: StructuredOCRNetworkIsolation = .operatingSystemSandbox
    public let bubblewrapURL: URL
    public let systemReadOnlyPaths: [URL]
    public let devicePaths: [URL]

    private let launcher: any StructuredOCRProcessRunning

    public init(
        bubblewrapURL: URL = URL(fileURLWithPath: "/usr/bin/bwrap"),
        systemReadOnlyPaths: [URL] = Self.defaultSystemReadOnlyPaths,
        devicePaths: [URL] = [],
        launcher: any StructuredOCRProcessRunning = SubprocessStructuredOCRRunner()
    ) {
        self.bubblewrapURL = bubblewrapURL
        self.systemReadOnlyPaths = systemReadOnlyPaths
        self.devicePaths = devicePaths
        self.launcher = launcher
    }

    public func run(executable: URL, arguments: [String]) throws -> StructuredOCRCommandResult {
        #if os(Linux)
        guard FileManager.default.isExecutableFile(atPath: bubblewrapURL.path) else {
            throw StructuredOCRProcessError.sandboxUnavailable
        }
        let invocation = try sandboxInvocation(executable: executable, arguments: arguments)
        let result = try launcher.run(executable: bubblewrapURL, arguments: invocation)
        if result.status != 0, isBubblewrapBootstrapFailure(result.standardError) {
            // Ubuntu 24.04 may install bwrap while AppArmor still blocks the
            // unprivileged user namespace it needs. Do not misreport that as
            // a provider/model failure or attempt an unsandboxed fallback.
            throw StructuredOCRProcessError.sandboxUnavailable
        }
        return result
        #else
        throw StructuredOCRProcessError.sandboxUnavailable
        #endif
    }

    func sandboxInvocation(executable: URL, arguments: [String]) throws -> [String] {
        let fileManager = FileManager.default
        let providerExecutable = executable.resolvingSymlinksInPath().standardizedFileURL
        let providerRoot = providerExecutable.deletingLastPathComponent()
        guard fileManager.isExecutableFile(atPath: providerExecutable.path) else {
            throw StructuredOCRProcessError.runtimeUnavailable
        }

        var sandboxArguments = [
            "--die-with-parent",
            "--new-session",
            "--unshare-net",
            "--unshare-pid",
            "--unshare-ipc",
            "--unshare-uts",
            "--cap-drop", "ALL",
            "--clearenv",
            "--setenv", "HOME", "/tmp",
            "--setenv", "TMPDIR", "/tmp",
            "--setenv", "XDG_CACHE_HOME", "/tmp/cache",
            "--setenv", "PATH", "/usr/bin:/bin",
            "--proc", "/proc",
            "--dev", "/dev",
            "--tmpfs", "/tmp",
            "--dir", "/app",
            "--dir", "/input",
            "--dir", "/work",
            "--dir", "/etc"
        ]

        for path in systemReadOnlyPaths.map(\.standardizedFileURL) where fileManager.fileExists(atPath: path.path) {
            sandboxArguments.append(contentsOf: ["--ro-bind", path.path, path.path])
        }
        sandboxArguments.append(contentsOf: ["--ro-bind", providerRoot.path, "/app/provider"])

        var providerArguments = arguments
        if arguments.first == "recognize" {
            guard let input = argumentValue(after: "--input", in: arguments),
                  let request = argumentValue(after: "--request", in: arguments),
                  let output = argumentValue(after: "--output", in: arguments) else {
                throw StructuredOCRProcessError.invalidInvocation
            }
            let inputURL = URL(fileURLWithPath: input).resolvingSymlinksInPath().standardizedFileURL
            let requestURL = URL(fileURLWithPath: request).resolvingSymlinksInPath().standardizedFileURL
            let outputURL = URL(fileURLWithPath: output).standardizedFileURL
            let workDirectory = outputURL.deletingLastPathComponent()

            guard isRegularFile(inputURL), isRegularFile(requestURL),
                  fileManager.fileExists(atPath: workDirectory.path) else {
                throw StructuredOCRProcessError.invalidInvocation
            }

            sandboxArguments.append(contentsOf: ["--bind", workDirectory.path, "/work"])
            sandboxArguments.append(contentsOf: ["--ro-bind", inputURL.path, "/input/document.pdf"])
            sandboxArguments.append(contentsOf: ["--ro-bind", requestURL.path, "/work/request.json"])
            replaceArgument(after: "--input", with: "/input/document.pdf", in: &providerArguments)
            replaceArgument(after: "--request", with: "/work/request.json", in: &providerArguments)
            replaceArgument(after: "--output", with: "/work/document-ir.json", in: &providerArguments)
        } else if arguments.first != "capabilities" {
            throw StructuredOCRProcessError.invalidInvocation
        }

        var deviceParents = Set<String>()
        for device in devicePaths.map(\.standardizedFileURL) where fileManager.fileExists(atPath: device.path) {
            let parent = device.deletingLastPathComponent().path
            if parent != "/dev", deviceParents.insert(parent).inserted {
                sandboxArguments.append(contentsOf: ["--dir", parent])
            }
            sandboxArguments.append(contentsOf: ["--dev-bind", device.path, device.path])
        }

        sandboxArguments.append(contentsOf: [
            "--chdir", "/app/provider",
            "--",
            "/app/provider/\(providerExecutable.lastPathComponent)"
        ])
        sandboxArguments.append(contentsOf: providerArguments)
        return sandboxArguments
    }

    public static var defaultSystemReadOnlyPaths: [URL] {
        [
            "/usr",
            "/bin",
            "/lib",
            "/lib64",
            "/etc/ld.so.cache",
            "/etc/ssl/certs",
            "/etc/fonts"
        ].map { URL(fileURLWithPath: $0) }
    }

    private func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private func replaceArgument(after flag: String, with value: String, in arguments: inout [String]) {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return }
        arguments[index + 1] = value
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return false }
        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private func isBubblewrapBootstrapFailure(_ standardError: Data) -> Bool {
        String(decoding: standardError, as: UTF8.self)
            .split(whereSeparator: { $0.isNewline })
            .contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("bwrap:") }
    }
}
