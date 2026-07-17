// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AZpdf",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AZpdfCore", targets: ["AZpdfCore"]),
        .executable(name: "AZpdf", targets: ["AZpdf"])
    ],
    targets: [
        .target(name: "AZpdfCore", path: "Core"),
        .executableTarget(name: "AZpdf", dependencies: ["AZpdfCore"], path: ".", exclude: [".github", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", "ROADMAP.md", "Assets", "Config", "Core", "Plugins", "docs", "script", ".codex", "dist", "Tests"], sources: ["App", "Models", "Services", "Stores", "Support", "Views"]),
        .testTarget(name: "AZpdfTests", dependencies: ["AZpdf", "AZpdfCore"], path: "Tests/AZpdfTests"),
        .testTarget(name: "AZpdfCoreTests", dependencies: ["AZpdfCore"], path: "Tests/AZpdfCoreTests")
    ]
)
