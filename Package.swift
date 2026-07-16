// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AZpdf",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AZpdf", targets: ["AZpdf"])],
    targets: [
        .executableTarget(name: "AZpdf", path: ".", exclude: [".github", "README.md", "LICENSE", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", "ROADMAP.md", "Assets", "Plugins", "docs", "script", ".codex", "dist", "Tests"], sources: ["App", "Models", "Services", "Stores", "Support", "Views"]),
        .testTarget(name: "AZpdfTests", dependencies: ["AZpdf"], path: "Tests/AZpdfTests")
    ]
)
