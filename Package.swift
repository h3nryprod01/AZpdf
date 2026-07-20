// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "AZpdfCore", targets: ["AZpdfCore"]),
    .library(name: "AZpdfMuPDF", targets: ["AZpdfMuPDF"]),
    .library(name: "AZpdfPAdES", targets: ["AZpdfPAdES"]),
    .library(name: "AZpdfStructuredOCR", targets: ["AZpdfStructuredOCR"]),
    .executable(name: "azpdf-engine", targets: ["AZpdfEngineCLI"])
]

var targets: [Target] = [
    .target(name: "AZpdfCore", path: "Core"),
    .target(
        name: "AZpdfMuPDF",
        dependencies: [
            "AZpdfCore",
            .product(name: "Subprocess", package: "swift-subprocess")
        ],
        path: "Adapters/MuPDF",
        resources: [.copy("Resources")]
    ),
    .target(
        name: "AZpdfPAdES",
        dependencies: [
            "AZpdfCore",
            .product(name: "Subprocess", package: "swift-subprocess")
        ],
        path: "Adapters/PAdES"
    ),
    .target(
        name: "AZpdfStructuredOCR",
        dependencies: [
            "AZpdfCore",
            .product(name: "Subprocess", package: "swift-subprocess")
        ],
        path: "Adapters/StructuredOCR"
    ),
    .executableTarget(
        name: "AZpdfEngineCLI",
        dependencies: ["AZpdfCore", "AZpdfMuPDF", "AZpdfPAdES"],
        path: "Tools/AZpdfEngineCLI",
        linkerSettings: [
            .unsafeFlags(
                ["-Xlinker", "-z", "-Xlinker", "relro", "-Xlinker", "-z", "-Xlinker", "now"],
                .when(platforms: [.linux])
            )
        ]
    ),
    .testTarget(name: "AZpdfCoreTests", dependencies: ["AZpdfCore"], path: "Tests/AZpdfCoreTests"),
    .testTarget(name: "AZpdfMuPDFTests", dependencies: ["AZpdfMuPDF", "AZpdfCore"], path: "Tests/AZpdfMuPDFTests"),
    .testTarget(name: "AZpdfPAdESTests", dependencies: ["AZpdfPAdES", "AZpdfCore"], path: "Tests/AZpdfPAdESTests"),
    .testTarget(
        name: "AZpdfStructuredOCRTests",
        dependencies: ["AZpdfStructuredOCR", "AZpdfCore"],
        path: "Tests/AZpdfStructuredOCRTests"
    )
]

#if os(macOS)
products.append(.executable(name: "AZpdf", targets: ["AZpdf"]))
targets.append(
    .executableTarget(
        name: "AZpdf",
        dependencies: ["AZpdfCore"],
        path: ".",
        exclude: [".github", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", "ROADMAP.md", "Adapters", "Assets", "Config", "Core", "Plugins", "Shell", "Tools", "docs", "qa-report", "script", ".codex", "dist", "Tests"],
        sources: ["App", "Models", "Services", "Stores", "Support", "Views"]
    )
)
targets.append(.testTarget(name: "AZpdfTests", dependencies: ["AZpdf", "AZpdfCore"], path: "Tests/AZpdfTests"))
#endif

let package = Package(
    name: "AZpdf",
    platforms: [.macOS(.v14)],
    products: products,
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-subprocess.git",
            revision: "11633673a41f509f8945f23c96c7acd4adafd679"
        )
    ],
    targets: targets
)
