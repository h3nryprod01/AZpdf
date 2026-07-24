import Foundation
import PDFKit

enum MuPDFImageOverlayError: LocalizedError {
    case runtimeUnavailable
    case scriptUnavailable
    case cannotWriteInput
    case processFailed(String)
    case cannotReadOutput

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable: L("MuPDF runtime missing. Install it via Homebrew, or use an AZpdf build that bundles the runtime.")
        case .scriptUnavailable: L("Could not find the AZpdf image-overlay script.")
        case .cannotWriteInput: L("Could not prepare the temporary PDF for image insertion.")
        case let .processFailed(message): L("MuPDF could not insert the image: \(message)")
        case .cannotReadOutput: L("Could not read the PDF after inserting the image.")
        }
    }
}

enum MuPDFImageOverlayService {
    static func insertImage(_ imageURL: URL, into document: PDFDocument, pageIndex: Int, bounds: CGRect) throws -> PDFDocument {
        guard let mutool = runtimeURL() else { throw MuPDFImageOverlayError.runtimeUnavailable }
        guard let script = Bundle.main.url(forResource: "mupdf_add_image", withExtension: "js") else {
            throw MuPDFImageOverlayError.scriptUnavailable
        }
        let directory = FileManager.default.temporaryDirectory.appending(path: "AZpdf-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appending(path: "input.pdf")
        let output = directory.appending(path: "output.pdf")
        guard document.write(to: input) else { throw MuPDFImageOverlayError.cannotWriteInput }

        let process = Process()
        let errors = Pipe()
        process.executableURL = mutool
        process.arguments = ["run", script.path, input.path, imageURL.path, "\(pageIndex)", "\(bounds.minX)", "\(bounds.minY)", "\(bounds.width)", "\(bounds.height)", output.path]
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
            throw MuPDFImageOverlayError.processFailed(message)
        }
        guard let updated = PDFDocument(url: output) else { throw MuPDFImageOverlayError.cannotReadOutput }
        return updated
    }

    private static func runtimeURL() -> URL? {
        let candidates = [
            Bundle.main.bundleURL.appending(path: "Contents/Resources/Helpers/mutool"),
            Bundle.main.url(forResource: "mutool", withExtension: nil, subdirectory: "Tools"),
            URL(fileURLWithPath: "/opt/homebrew/bin/mutool"),
            URL(fileURLWithPath: "/usr/local/bin/mutool")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
