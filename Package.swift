// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AZpdf",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AZpdf", targets: ["AZpdf"])],
    targets: [
        .executableTarget(name: "AZpdf", path: ".", exclude: ["README.md", "LICENSE", "CONTRIBUTING.md", "SECURITY.md", "Assets", "script", ".codex", "dist", "Tests"], sources: ["App", "Models", "Stores", "Support", "Views"]),
        .testTarget(name: "AZpdfTests", dependencies: ["AZpdf"], path: "Tests/AZpdfTests")
    ]
)
