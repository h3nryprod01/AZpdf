import Foundation

enum OCRMyPDFError: LocalizedError {
    case runtimeUnavailable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            "Chưa có OCRmyPDF runtime. Bản phát hành AZpdf phải đi kèm OCRmyPDF, Tesseract, Ghostscript và language data."
        case let .exportFailed(message):
            "Không thể tạo PDF có lớp chữ: \(message)"
        }
    }
}

/// Creates a new searchable PDF with OCRmyPDF. `--skip-text` retains existing
/// born-digital text and only adds a text layer to pages that need OCR.
enum OCRMyPDFService {
    static func createSearchablePDF(
        documentData: Data,
        language: String = "eng",
        executable explicitExecutable: URL? = nil
    ) throws -> Data {
        guard let executable = explicitExecutable ?? runtimeURL() else { throw OCRMyPDFError.runtimeUnavailable }
        let directory = FileManager.default.temporaryDirectory.appending(path: "AZpdf-OCRmyPDF-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appending(path: "input.pdf")
        let output = directory.appending(path: "searchable.pdf")
        try documentData.write(to: input, options: .atomic)

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executable
        process.arguments = ["--skip-text", "--output-type", "pdf", "--language", language, input.path, output.path]
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = runtimeEnvironment(for: executable)
        try process.run()
        process.waitUntilExit()
        let message = [
            String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
            String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: output.path) else {
            throw OCRMyPDFError.exportFailed(message)
        }
        return try Data(contentsOf: output)
    }

    private static func runtimeURL() -> URL? {
        let candidates = [
            Bundle.main.bundleURL.appending(path: "Contents/Helpers/ocrmypdf/ocrmypdf"),
            Bundle.main.url(forResource: "ocrmypdf", withExtension: nil, subdirectory: "Tools/ocrmypdf"),
            URL(fileURLWithPath: "/opt/homebrew/opt/ocrmypdf/bin/ocrmypdf"),
            URL(fileURLWithPath: "/usr/local/bin/ocrmypdf")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func runtimeEnvironment(for executable: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        guard executable.path.contains("/Helpers/ocrmypdf/") || executable.path.contains("/Tools/ocrmypdf/") else { return environment }
        let runtime = executable.deletingLastPathComponent()
        let tools = runtime.deletingLastPathComponent()
        environment["PATH"] = [runtime.appending(path: "bin").path, runtime.path, tools.path, environment["PATH"]]
            .compactMap { $0 }
            .joined(separator: ":")
        let tessdata = runtime.appending(path: "tessdata", directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: tessdata.path) { environment["TESSDATA_PREFIX"] = tessdata.path }
        return environment
    }
}
