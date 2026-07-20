import Foundation
import Dispatch
import Subprocess
import AZpdfCore

public struct MuPDFCommandResult: Equatable, Sendable {
    public let status: Int32
    public let standardOutput: Data
    public let standardError: Data

    public init(status: Int32, standardOutput: Data = Data(), standardError: Data = Data()) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public protocol MuPDFCommandRunning {
    func run(executable: URL, arguments: [String]) throws -> MuPDFCommandResult
}

public struct SubprocessMuPDFCommandRunner: MuPDFCommandRunning {
    public let timeout: TimeInterval
    public let maximumCapturedOutputBytes: Int

    public init(timeout: TimeInterval = 30, maximumCapturedOutputBytes: Int = 32 * 1_024 * 1_024) {
        self.timeout = max(0.1, timeout)
        self.maximumCapturedOutputBytes = max(1_024, maximumCapturedOutputBytes)
    }

    public func run(executable: URL, arguments: [String]) throws -> MuPDFCommandResult {
        let completion = MuPDFCommandCompletion()
        let semaphore = DispatchSemaphore(value: 0)
        let outputLimit = maximumCapturedOutputBytes
        let executablePath = executable.path
        let task = Task.detached(priority: .userInitiated) {
            do {
                var platformOptions = Subprocess.PlatformOptions()
                platformOptions.teardownSequence = [
                    .gracefulShutDown(allowedDurationToNextStep: .milliseconds(250))
                ]
                let result = try await Subprocess.run(
                    .path(.init(executablePath)),
                    arguments: Arguments(arguments),
                    platformOptions: platformOptions,
                    output: .data(limit: outputLimit),
                    error: .data(limit: outputLimit)
                )
                let status: Int32
                switch result.terminationStatus {
                case let .exited(code):
                    status = Int32(truncatingIfNeeded: code)
                #if !os(Windows)
                case let .signaled(signal):
                    status = 128 + Int32(signal)
                #endif
                }
                completion.store(.success(MuPDFCommandResult(
                    status: status,
                    standardOutput: result.standardOutput,
                    standardError: result.standardError
                )))
            } catch {
                completion.store(.failure(error))
            }
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            task.cancel()
            _ = semaphore.wait(timeout: .now() + 2)
            throw PDFEngineError.ioFailure("MuPDF vượt quá timeout \(timeout) giây.")
        }
        guard let result = completion.take() else {
            throw PDFEngineError.ioFailure("MuPDF kết thúc mà không trả kết quả.")
        }
        do {
            return try result.get()
        } catch {
            throw PDFEngineError.ioFailure("Không thể chạy MuPDF: \(String(describing: error))")
        }
    }
}

private final class MuPDFCommandCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<MuPDFCommandResult, Error>?

    func store(_ result: Result<MuPDFCommandResult, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func take() -> Result<MuPDFCommandResult, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

public final class MuPDFDocument {
    fileprivate var data: Data
    fileprivate let numberOfPages: Int

    fileprivate init(data: Data, numberOfPages: Int) {
        self.data = data
        self.numberOfPages = numberOfPages
    }
}

/// Read-only CLI prototype. The production adapter will replace the process
/// boundary with a sandboxed worker/C FFI after fidelity and fuzz gates pass.
public struct MuPDFDocumentEngine: PDFDocumentReadingEngine, PDFDocumentStructuredTextEngine {
    public let executableURL: URL
    public let capabilities: PDFEngineCapabilities = [
        .open, .save, .render, .extractText, .search, .metadata, .annotations, .structuredText
    ]

    private let runner: any MuPDFCommandRunning

    public init(
        executableURL: URL,
        runner: any MuPDFCommandRunning = SubprocessMuPDFCommandRunner()
    ) {
        self.executableURL = executableURL
        self.runner = runner
    }

    public func load(data: Data) throws -> MuPDFDocument {
        try withTemporaryDocument(data) { input, _ in
            let result = try checkedRun(["pages", input.path])
            let output = string(result.standardOutput)
            let count = output.components(separatedBy: "<page ").count - 1
            guard count > 0 else { throw PDFEngineError.invalidDocument }
            return MuPDFDocument(data: data, numberOfPages: count)
        }
    }

    public func dataRepresentation(of document: MuPDFDocument) throws -> Data {
        document.data
    }

    public func pageCount(of document: MuPDFDocument) -> Int {
        document.numberOfPages
    }

    public func apply(_ operation: DocumentOperation, to document: MuPDFDocument) throws {
        switch operation {
        case let .upsertAnnotation(descriptor):
            guard descriptor.kind == .freeText || descriptor.kind == .note else {
                throw PDFEngineError.operationNotSupported
            }
            try upsertAnnotation(descriptor, image: nil, in: document)
        case let .upsertImageAnnotation(descriptor, imageData, format):
            guard descriptor.kind == .image else { throw PDFEngineError.operationNotSupported }
            try upsertAnnotation(
                descriptor,
                image: imageData.map { ($0, format) },
                in: document
            )
        case let .removeAnnotation(id, page):
            try removeAnnotation(id: id, page: page, from: document)
        default:
            throw PDFEngineError.operationNotSupported
        }
    }

    public func metadata(of document: MuPDFDocument) throws -> PDFDocumentMetadata {
        try withTemporaryDocument(document.data) { input, _ in
            let result = try checkedRun(["show", input.path, "trailer/Info"])
            let output = string(result.standardOutput)
            return PDFDocumentMetadata(
                title: pdfString(named: "Title", in: output),
                author: pdfString(named: "Author", in: output),
                subject: pdfString(named: "Subject", in: output),
                keywords: pdfString(named: "Keywords", in: output)?
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? [],
                creator: pdfString(named: "Creator", in: output),
                producer: pdfString(named: "Producer", in: output),
                language: pdfString(named: "Lang", in: output)
            )
        }
    }

    public func pageDescriptor(at index: Int, in document: MuPDFDocument) throws -> PDFPageDescriptor {
        guard (0..<document.numberOfPages).contains(index) else { throw PDFEngineError.invalidPageIndex }
        return try withTemporaryDocument(document.data) { input, _ in
            let result = try checkedRun(["pages", input.path, "\(index + 1)"])
            let output = string(result.standardOutput)
            guard let media = box(named: "MediaBox", in: output) else {
                throw PDFEngineError.invalidDocument
            }
            let crop = box(named: "CropBox", in: output) ?? media
            let rotation = firstMatch(#"<Rotate v="([^"]+)""#, in: output)
                .flatMap(Int.init) ?? 0
            return PDFPageDescriptor(
                index: index,
                mediaBox: media,
                cropBox: crop,
                rotation: rotation
            )
        }
    }

    public func text(ofPage index: Int, in document: MuPDFDocument) throws -> String {
        guard (0..<document.numberOfPages).contains(index) else { throw PDFEngineError.invalidPageIndex }
        return try withTemporaryDocument(document.data) { input, directory in
            let output = directory.appendingPathComponent("page.txt")
            _ = try checkedRun([
                "draw", "-q", "-F", "txt", "-o", output.path, input.path, "\(index + 1)"
            ])
            return try String(contentsOf: output, encoding: .utf8)
        }
    }

    public func annotations(onPage index: Int, in document: MuPDFDocument) throws -> [PDFAnnotationDescriptor] {
        guard (0..<document.numberOfPages).contains(index) else { throw PDFEngineError.invalidPageIndex }
        return try withTemporaryDocument(document.data) { input, _ in
            let result = try checkedRun([
                "run", try annotationScriptURL().path, "list", input.path, "\(index)"
            ])
            do {
                return try JSONDecoder().decode([PDFAnnotationDescriptor].self, from: result.standardOutput)
            } catch {
                throw PDFEngineError.ioFailure("Không thể đọc annotation MuPDF: \(error.localizedDescription)")
            }
        }
    }

    public func structuredText(ofPage index: Int, in document: MuPDFDocument) throws -> PDFPageTextLayout {
        guard (0..<document.numberOfPages).contains(index) else { throw PDFEngineError.invalidPageIndex }
        return try withTemporaryDocument(document.data) { input, directory in
            let output = directory.appendingPathComponent("page.json")
            _ = try checkedRun([
                "draw", "-q", "-F", "stext.json", "-o", output.path, input.path, "\(index + 1)"
            ])
            let decoded = try JSONDecoder().decode(MuPDFStructuredText.self, from: Data(contentsOf: output))
            guard let page = decoded.pages.first else { throw PDFEngineError.invalidDocument }
            return PDFPageTextLayout(
                pageIndex: index,
                coordinateSpace: .pageTopLeft,
                blocks: page.blocks.map { block in
                    PDFTextBlock(
                        kind: PDFTextBlockKind(rawValue: block.type) ?? .unknown,
                        bounds: block.bbox.portable,
                        lines: (block.lines ?? []).map { line in
                            PDFTextLine(
                                bounds: line.bbox.portable,
                                text: line.text,
                                fontName: line.font?.name,
                                fontFamily: line.font?.family,
                                fontSize: line.font?.size,
                                writingMode: line.wmode
                            )
                        }
                    )
                }
            )
        }
    }

    public func render(_ request: PDFRenderRequest, in document: MuPDFDocument) throws -> PDFRenderedPage {
        guard request.scale > 0, (0..<document.numberOfPages).contains(request.pageIndex) else {
            throw PDFEngineError.invalidPageIndex
        }
        let page = try pageDescriptor(at: request.pageIndex, in: document)
        return try withTemporaryDocument(document.data) { input, directory in
            let output = directory.appendingPathComponent("page.png")
            let dpi = max(4, Int((72 * request.scale).rounded()))
            _ = try checkedRun([
                "draw", "-q", "-F", "png", "-r", "\(dpi)",
                "-o", output.path, input.path, "\(request.pageIndex + 1)"
            ])
            let data = try Data(contentsOf: output)
            let rotated = page.rotation == 90 || page.rotation == 270
            let baseSize = page.cropBox.size
            let width = (rotated ? baseSize.height : baseSize.width) * request.scale
            let height = (rotated ? baseSize.width : baseSize.height) * request.scale
            return PDFRenderedPage(
                size: PDFSize(width: width, height: height),
                format: .png,
                data: data,
                pageBox: page.cropBox,
                rotation: page.rotation
            )
        }
    }

    private func checkedRun(_ arguments: [String]) throws -> MuPDFCommandResult {
        let result = try runner.run(executable: executableURL, arguments: arguments)
        guard result.status == 0 else {
            let message = string(result.standardError).trimmingCharacters(in: .whitespacesAndNewlines)
            throw PDFEngineError.ioFailure(message.isEmpty ? "MuPDF trả mã lỗi \(result.status)." : message)
        }
        return result
    }

    private func annotationScriptURL() throws -> URL {
        if let script = Bundle.module.url(
            forResource: "azpdf_annotations",
            withExtension: "js",
            subdirectory: "Resources"
        ) ?? Bundle.module.url(forResource: "azpdf_annotations", withExtension: "js") {
            return script
        }
        throw PDFEngineError.ioFailure("Không tìm thấy azpdf_annotations.js trong runtime.")
    }

    private func upsertAnnotation(
        _ descriptor: PDFAnnotationDescriptor,
        image: (data: Data, format: PDFImageFormat)?,
        in document: MuPDFDocument
    ) throws {
        guard descriptor.coordinateSpace == .pdfBottomLeft,
              (0..<document.numberOfPages).contains(descriptor.pageIndex),
              descriptor.bounds.size.width > 0,
              descriptor.bounds.size.height > 0
        else { throw PDFEngineError.invalidPageIndex }

        let payloadData = try JSONEncoder().encode(descriptor)
        guard let payload = String(data: payloadData, encoding: .utf8) else {
            throw PDFEngineError.ioFailure("Không thể mã hóa annotation.")
        }
        try withTemporaryDocument(document.data) { input, directory in
            let output = directory.appendingPathComponent("edited.pdf")
            var arguments = [
                "run", try annotationScriptURL().path, "upsert",
                input.path, output.path, payload
            ]
            if let image {
                let imageURL = directory.appendingPathComponent("annotation.\(image.format.rawValue)")
                try image.data.write(to: imageURL, options: .atomic)
                arguments.append(imageURL.path)
            }
            _ = try checkedRun(arguments)
            let updated = try Data(contentsOf: output)
            _ = try load(data: updated)
            document.data = updated
        }
    }

    private func removeAnnotation(id: String, page: Int, from document: MuPDFDocument) throws {
        guard (0..<document.numberOfPages).contains(page) else { throw PDFEngineError.invalidPageIndex }
        try withTemporaryDocument(document.data) { input, directory in
            let output = directory.appendingPathComponent("edited.pdf")
            _ = try checkedRun([
                "run", try annotationScriptURL().path, "remove",
                input.path, output.path, "\(page)", id
            ])
            let updated = try Data(contentsOf: output)
            _ = try load(data: updated)
            document.data = updated
        }
    }

    private func withTemporaryDocument<T>(
        _ data: Data,
        body: (URL, URL) throws -> T
    ) throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("azpdf-mupdf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("input.pdf")
        try data.write(to: input, options: .atomic)
        return try body(input, directory)
    }

    private func string(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
    }

    private func box(named name: String, in output: String) -> PDFRect? {
        let pattern = #"<\#(name) l="([^"]+)" b="([^"]+)" r="([^"]+)" t="([^"]+)""#
        let values = matches(pattern, in: output)
        guard values.count == 4,
              let left = Double(values[0]),
              let bottom = Double(values[1]),
              let right = Double(values[2]),
              let top = Double(values[3])
        else { return nil }
        return PDFRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }

    private func pdfString(named name: String, in output: String) -> String? {
        firstMatch(#"/\#(name)\s*\((.*?)\)"#, in: output)?
            .replacingOccurrences(of: #"\("#, with: "(")
            .replacingOccurrences(of: #"\)"#, with: ")")
            .replacingOccurrences(of: #"\\"#, with: #"\"#)
    }

    private func firstMatch(_ pattern: String, in value: String) -> String? {
        matches(pattern, in: value).first
    }

    private func matches(_ pattern: String, in value: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, range: range) else { return [] }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: value).map { String(value[$0]) }
        }
    }
}

private struct MuPDFStructuredText: Decodable {
    let pages: [Page]

    struct Page: Decodable {
        let blocks: [Block]
    }

    struct Block: Decodable {
        let type: String
        let bbox: Box
        let lines: [Line]?
    }

    struct Line: Decodable {
        let wmode: Int
        let bbox: Box
        let font: Font?
        let text: String
    }

    struct Font: Decodable {
        let name: String?
        let family: String?
        let size: Double?
    }

    struct Box: Decodable {
        let x: Double
        let y: Double
        let w: Double
        let h: Double

        var portable: PDFRect { PDFRect(x: x, y: y, width: w, height: h) }
    }
}
