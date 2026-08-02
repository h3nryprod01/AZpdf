// swift-tools-version: 6.2
// 6.2 là sàn THẬT, và nó không đến từ code của dự án này.
//
// Bản trước ghi 6.3 với lý do: mẫu `DispatchQueue.main.async` + `@MainActor` trong
// `DocumentStore+OCR.swift` bị Swift 6.2.4 từ chối. Lý do đó **đã hết hiệu lực** — PHA 3
// gỡ toàn bộ 10/10 chỗ đó sang `Task`/`async` (không còn `DispatchQueue` nào trong
// `Stores/` lẫn `Views/`).
//
// Thử hạ thẳng xuống 6.0 thì CI trả lời dứt khoát, và trả lời một chuyện khác hẳn:
//   error: package 'swift-subprocess' is using Swift tools version 6.2.0
//          but the installed version is 6.1.0
// Sàn do **dependency** đặt ra, không phải do code ở đây. `swift-subprocess` (đã ghim theo
// revision) tự khai `swift-tools-version: 6.2`, nên 6.2 là mức thấp nhất có thể — hạ nữa
// là SwiftPM từ chối resolve, bất kể code của ta viết thế nào.
//
// Nói cách khác: cái giá "chặn người dùng Swift 6.0-6.2" mà bản trước tự nhận là đã trả,
// thực ra chỉ chặn 6.0-6.1, và không phải do ta chọn.
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
