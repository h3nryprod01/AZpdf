// swift-tools-version: 6.3
// 6.3 is the real floor, not a preference. The macOS app target uses a
// DispatchQueue.main.async + @MainActor pattern (DocumentStore+OCR.swift) that
// Swift 6.2.4 rejects with "sending 'self' risks causing data races" and 6.3
// accepts. Declaring 6.0 did not make those toolchains work — it only turned a
// clear "this package requires 6.3" into a confusing concurrency error, and it
// kept CI red for ten runs while the cause looked like a code bug. CI, the
// release scripts and the Linux container all pin 6.3.3 already.
//
// The cost is real and deliberate: the portable products (AZpdfCore and
// azpdf-engine) do compile under 6.0-6.2, and this manifest now refuses those
// toolchains for everyone, since a package has one tools-version rather than
// one per target. Building the engine on an older Swift means pinning an older
// tag. That is the honest trade for a requirement that is stated instead of
// discovered halfway through a build.
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
        exclude: [".github", "README.md", "README-VI.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "CONTRIBUTING.md", "CONTRIBUTING-VI.md", "SECURITY.md", "SECURITY-VI.md",
                   "CODE_OF_CONDUCT.md", "CODE_OF_CONDUCT-VI.md", "ROADMAP.md", "Adapters", "Assets", "Config", "Core", "Plugins", "Shell", "Tools", "docs", "qa-report", "script", ".codex", "dist", "Tests"],
        sources: ["App", "Models", "Services", "Stores", "Support", "Views"],
        resources: [.process("Resources")]
    )
)
targets.append(.testTarget(name: "AZpdfTests", dependencies: ["AZpdf", "AZpdfCore"], path: "Tests/AZpdfTests"))
#endif

let package = Package(
    name: "AZpdf",
    defaultLocalization: "en",
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
