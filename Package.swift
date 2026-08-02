// swift-tools-version: 6.3
// 6.3 là sàn thật — nhưng KHÔNG phải vì lý do bản trước ghi. Ba lần đo, ba lý do khác nhau,
// mỗi lần bác bỏ lần trước:
//
//   1. Giả định cũ: "code ta dùng DispatchQueue+@MainActor mà 6.2.4 từ chối".
//      → HẾT HIỆU LỰC. PHA 3 gỡ 10/10 chỗ sang Task/async; `Stores/` và `Views/` không còn
//        `DispatchQueue` nào.
//   2. Thử hạ 6.0 → SwiftPM từ chối trước cả khi biên dịch:
//        package 'swift-subprocess' is using Swift tools version 6.2.0
//      Dependency đặt sàn, không phải ta. Vậy 6.2 là mức thấp nhất khai được.
//   3. Đặt 6.2 và build bằng toolchain 6.2 THẬT → code của dự án biên dịch sạch, nhưng
//      `swift-system` (bắc cầu qua swift-subprocess) gãy:
//        Constants.swift:680: cannot find 'AT_RESOLVE_BENEATH' in scope
//      Hằng số đó cần SDK mới hơn bản mà Swift 6.2 mang theo.
//
// Nên sàn 6.3 giữ nguyên, và giờ lý do là đúng: nó do **SDK mà dependency cần**, không phải
// do concurrency trong code ứng dụng. Ai muốn hạ tiếp thì phải giải bài swift-system/SDK,
// đừng đi sửa lại code app — hướng đó đã đo và đã hết.
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
