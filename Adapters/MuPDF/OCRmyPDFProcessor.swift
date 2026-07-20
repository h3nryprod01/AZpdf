import Foundation
import AZpdfCore

public struct OCRmyPDFProcessor: PDFOCRProcessor {
    public let executableURL: URL
    private let runner: any MuPDFCommandRunning

    public init(
        executableURL: URL,
        runner: any MuPDFCommandRunning = SubprocessMuPDFCommandRunner(
            timeout: 20 * 60,
            maximumCapturedOutputBytes: 8 * 1_024 * 1_024
        )
    ) {
        self.executableURL = executableURL
        self.runner = runner
    }

    public func capabilities() throws -> PDFOCRCapabilities {
        let result = try runner.run(executable: executableURL, arguments: ["--version"])
        guard result.status == 0 else {
            throw PDFEngineError.ioFailure(message(from: result, fallback: "Không đọc được phiên bản OCRmyPDF."))
        }
        let version = String(decoding: result.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PDFOCRCapabilities(
            provider: "OCRmyPDF",
            version: version.isEmpty ? "unknown" : version,
            executable: executableURL.path,
            features: [.searchablePDF, .visualLayoutPreservation]
        )
    }

    public func process(
        _ request: PDFOCRRequest,
        input: URL,
        output: URL
    ) throws -> PDFOCRResult {
        guard isValidLanguage(request.language), input.standardizedFileURL != output.standardizedFileURL else {
            throw PDFEngineError.ioFailure("Yêu cầu OCR không hợp lệ.")
        }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: input.path) else {
            throw PDFEngineError.ioFailure("Không tìm thấy PDF nguồn để OCR.")
        }
        try fileManager.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: output.path) {
            try fileManager.removeItem(at: output)
        }

        var arguments = ["--output-type", "pdf", "--language", request.language]
        if request.skipText { arguments.append("--skip-text") }
        if request.deskew { arguments.append("--deskew") }
        if request.rotatePages { arguments.append("--rotate-pages") }
        arguments.append(contentsOf: [input.path, output.path])

        let result = try runner.run(executable: executableURL, arguments: arguments)
        guard result.status == 0,
              fileManager.fileExists(atPath: output.path),
              let attributes = try? fileManager.attributesOfItem(atPath: output.path),
              let bytes = attributes[.size] as? NSNumber,
              bytes.intValue > 0
        else {
            throw PDFEngineError.ioFailure(message(from: result, fallback: "OCRmyPDF không tạo được PDF đầu ra."))
        }
        let capabilities = try capabilities()
        return PDFOCRResult(
            provider: capabilities.provider,
            version: capabilities.version,
            language: request.language,
            output: output,
            bytes: bytes.intValue,
            features: capabilities.features
        )
    }

    private func isValidLanguage(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || "_+-".unicodeScalars.contains($0)
        }
    }

    private func message(from result: MuPDFCommandResult, fallback: String) -> String {
        let values = [result.standardError, result.standardOutput]
            .map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? fallback : values.joined(separator: "\n")
    }
}
