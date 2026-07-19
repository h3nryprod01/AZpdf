import Foundation
import AZpdfCore
import AZpdfMuPDF
import AZpdfPAdES

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WinSDK)
import WinSDK
#endif

private let protocolVersion = 1

@main
struct AZpdfEngineCLI {
    static func main() {
        do {
            let arguments = try Arguments(CommandLine.arguments)
            if try handlePortableCommand(arguments) { return }
            let mutool = try MuPDFRuntimeLocator.locate(explicitPath: arguments.optional("--mutool"))
            let engine = MuPDFDocumentEngine(executableURL: mutool)

            switch arguments.command {
            case "health": try handleHealth(arguments, engine: engine, mutool: mutool)
            case "ocr-health": try handleOCRHealth(arguments, engine: engine, mutool: mutool)
            case "signature-health": try handleSignatureHealth(arguments, engine: engine, mutool: mutool)
            case "info": try handleInfo(arguments, engine: engine, mutool: mutool)
            case "page": try handlePage(arguments, engine: engine, mutool: mutool)
            case "render": try handleRender(arguments, engine: engine, mutool: mutool)
            case "text": try handleText(arguments, engine: engine, mutool: mutool)
            case "search": try handleSearch(arguments, engine: engine, mutool: mutool)
            case "annotations": try handleAnnotations(arguments, engine: engine, mutool: mutool)
            case "ir-baseline": try handleIRBaseline(arguments, engine: engine, mutool: mutool)
            case "upsert-annotation": try handleUpsertAnnotation(arguments, engine: engine, mutool: mutool)
            case "upsert-image-annotation": try handleUpsertImageAnnotation(arguments, engine: engine, mutool: mutool)
            case "remove-annotation": try handleRemoveAnnotation(arguments, engine: engine, mutool: mutool)
            case "ocr": try handleOCR(arguments, engine: engine, mutool: mutool)
            case "verify-signatures": try handleVerifySignatures(arguments, engine: engine, mutool: mutool)
            case "sign-pades": try handleSignPAdES(arguments, engine: engine, mutool: mutool)
            case "save-as": try handleSaveAs(arguments, engine: engine, mutool: mutool)
            default:
                throw CLIError.invalidCommand(arguments.command)
            }
        } catch {
            emit(FailureEnvelope(error: ErrorPayload(
                code: errorCode(error),
                message: localizedMessage(error)
            )))
            terminate(2)
        }
    }

    private static func handleHealth(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let runner = SubprocessMuPDFCommandRunner(timeout: 5, maximumCapturedOutputBytes: 1_024 * 1_024)
        let result = try runner.run(executable: mutool, arguments: ["-v"])
        guard result.status == 0 else {
            throw CLIError.engineFailure(String(decoding: result.standardError, as: UTF8.self))
        }
        let standardOutput = String(decoding: result.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let standardError = String(decoding: result.standardError, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        emit(Envelope(result: HealthResult(
            protocolVersion: protocolVersion,
            engine: "MuPDF",
            engineVersion: standardOutput.isEmpty ? standardError : standardOutput,
            executable: mutool.path
        )))
    }

    private static func handleOCRHealth(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let executable = try OCRRuntimeLocator.locate(
            explicitPath: arguments.optional("--ocrmypdf")
        )
        emit(Envelope(result: try OCRmyPDFProcessor(
            executableURL: executable
        ).capabilities()))
    }

    private static func handleSignatureHealth(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let executable = try PyHankoRuntimeLocator.locate(
            explicitPath: arguments.optional("--pyhanko")
        )
        emit(Envelope(result: try PyHankoSignatureProcessor(
            executableURL: executable
        ).capabilities()))
    }

    private static func handleInfo(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        emit(Envelope(result: DocumentInfoResult(
            protocolVersion: protocolVersion,
            pageCount: engine.pageCount(of: document),
            metadata: try engine.metadata(of: document),
            capabilities: capabilityNames(engine.capabilities)
        )))
    }

    private static func handlePage(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let index = try arguments.integer("--page", minimum: 0)
        emit(Envelope(result: try engine.pageDescriptor(at: index, in: document)))
    }

    private static func handleRender(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let index = try arguments.integer("--page", minimum: 0)
        let scale = try arguments.double("--scale", minimum: 0.05, defaultValue: 1)
        let output = URL(fileURLWithPath: try arguments.value("--output"))
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let rendered = try engine.render(
            PDFRenderRequest(pageIndex: index, scale: scale),
            in: document
        )
        try rendered.data.write(to: output, options: .atomic)
        emit(Envelope(result: RenderResult(
            page: index,
            width: rendered.size.width,
            height: rendered.size.height,
            format: rendered.format.rawValue,
            output: output.path,
            pageBox: rendered.pageBox,
            rotation: rendered.rotation
        )))
    }

    private static func handleText(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let index = try arguments.integer("--page", minimum: 0)
        emit(Envelope(result: TextResult(page: index, text: try engine.text(ofPage: index, in: document))))
    }

    private static func handleSearch(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let query = try arguments.value("--query")
        emit(Envelope(result: SearchResult(
            query: query,
            matches: try engine.search(query, in: document)
        )))
    }

    private static func handleAnnotations(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let index = try arguments.integer("--page", minimum: 0)
        emit(Envelope(result: AnnotationListResult(
            page: index,
            annotations: try engine.annotations(onPage: index, in: document)
        )))
    }

    private static func handleIRBaseline(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let source = URL(fileURLWithPath: try arguments.value("--document"))
        let document = try loadDocument(arguments: arguments, engine: engine)
        let indexes: [Int]
        if arguments.optional("--page") != nil {
            indexes = [try arguments.integer("--page", minimum: 0)]
        } else {
            indexes = Array(0..<engine.pageCount(of: document))
        }
        let descriptors = try indexes.map { try engine.pageDescriptor(at: $0, in: document) }
        let layouts = try indexes.map { try engine.structuredText(ofPage: $0, in: document) }
        let pdfMetadata = try engine.metadata(of: document)
        let ir = try DocumentIRBuilder.buildBaseline(
            layouts: layouts,
            pageDescriptors: descriptors,
            metadata: .init(
                title: pdfMetadata.title,
                sourceFilename: source.lastPathComponent,
                primaryLanguage: pdfMetadata.language
            ),
            provenance: .init(
                providerID: "org.azpdf.mupdf-stext",
                modelID: "MuPDF-stext-json",
                languages: pdfMetadata.language.map { [$0] } ?? [],
                options: ["semanticLevel": "baseline"]
            )
        )
        let output = URL(fileURLWithPath: try arguments.value("--output"))
        let data = try DocumentIRCodec.encode(ir, prettyPrinted: true)
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: output, options: .atomic)
        emit(Envelope(result: DocumentIRWriteResult(
            output: output.path,
            bytes: data.count,
            summary: documentIRSummary(ir)
        )))
    }

    private static func handleUpsertAnnotation(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let descriptor = try decodeAnnotation(arguments: arguments)
        try engine.apply(.upsertAnnotation(descriptor), to: document)
        emit(Envelope(result: try save(
            document: document,
            output: try arguments.value("--output"),
            engine: engine
        )))
    }

    private static func handleUpsertImageAnnotation(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let descriptor = try decodeAnnotation(arguments: arguments)
        let imagePath = arguments.optional("--image")
        let imageData = try imagePath.map {
            try Data(contentsOf: URL(fileURLWithPath: $0), options: [.mappedIfSafe])
        }
        let format = try imageFormat(arguments.optional("--format"), imagePath: imagePath)
        try engine.apply(
            .upsertImageAnnotation(descriptor, imageData: imageData, format: format),
            to: document
        )
        emit(Envelope(result: try save(
            document: document,
            output: try arguments.value("--output"),
            engine: engine
        )))
    }

    private static func handleRemoveAnnotation(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let index = try arguments.integer("--page", minimum: 0)
        try engine.apply(
            .removeAnnotation(id: try arguments.value("--id"), page: index),
            to: document
        )
        emit(Envelope(result: try save(
            document: document,
            output: try arguments.value("--output"),
            engine: engine
        )))
    }

    private static func handleOCR(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let pageCount = engine.pageCount(of: document)
        let output = URL(fileURLWithPath: try arguments.value("--output"))
        let processor = OCRmyPDFProcessor(
            executableURL: try OCRRuntimeLocator.locate(
                explicitPath: arguments.optional("--ocrmypdf")
            )
        )
        let result = try processor.process(
            PDFOCRRequest(
                language: arguments.optional("--language") ?? "eng",
                skipText: true,
                deskew: arguments.contains("--deskew"),
                rotatePages: arguments.contains("--rotate-pages")
            ),
            input: URL(fileURLWithPath: try arguments.value("--document")),
            output: output
        )
        let verified = try engine.load(data: Data(contentsOf: output, options: [.mappedIfSafe]))
        guard engine.pageCount(of: verified) == pageCount else {
            throw CLIError.invalidOCROutput
        }
        emit(Envelope(result: OCRCommandResult(result)))
    }

    private static func handleVerifySignatures(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        _ = try loadDocument(arguments: arguments, engine: engine)
        let processor = PyHankoSignatureProcessor(
            executableURL: try PyHankoRuntimeLocator.locate(
                explicitPath: arguments.optional("--pyhanko")
            )
        )
        emit(Envelope(result: try processor.verify(
            input: URL(fileURLWithPath: try arguments.value("--document"))
        )))
    }

    private static func handleSignPAdES(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let document = try loadDocument(arguments: arguments, engine: engine)
        let pageCount = engine.pageCount(of: document)
        let profileValue = arguments.optional("--profile") ?? PDFSignatureProfile.baselineB.rawValue
        guard let profile = PDFSignatureProfile(rawValue: profileValue) else {
            throw CLIError.invalidArgument("--profile", profileValue)
        }
        let output = URL(fileURLWithPath: try arguments.value("--output"))
        let processor = PyHankoSignatureProcessor(
            executableURL: try PyHankoRuntimeLocator.locate(
                explicitPath: arguments.optional("--pyhanko")
            )
        )
        let result = try processor.sign(
            PDFSignatureRequest(
                profile: profile,
                fieldSpec: arguments.optional("--field") ?? "1/36,36,260,96/AZpdfSignature",
                timestampURL: arguments.optional("--timestamp-url")
            ),
            input: URL(fileURLWithPath: try arguments.value("--document")),
            output: output,
            pkcs12: URL(fileURLWithPath: try arguments.value("--pkcs12")),
            passwordFile: URL(fileURLWithPath: try arguments.value("--passfile"))
        )
        let verified = try engine.load(data: Data(contentsOf: output, options: [.mappedIfSafe]))
        guard engine.pageCount(of: verified) == pageCount else {
            throw CLIError.invalidSignatureOutput
        }
        emit(Envelope(result: SignatureCommandResult(result)))
    }

    private static func handleSaveAs(_ arguments: Arguments, engine: MuPDFDocumentEngine, mutool: URL) throws {
        let source = URL(fileURLWithPath: try arguments.value("--document"))
        let destination = URL(fileURLWithPath: try arguments.value("--output"))
        let data = try Data(contentsOf: source, options: [.mappedIfSafe])
        _ = try engine.load(data: data)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
        emit(Envelope(result: SaveResult(output: destination.path, bytes: data.count)))
    }

    private static func handlePortableCommand(_ arguments: Arguments) throws -> Bool {
        switch arguments.command {
        case "ir-validate":
            let document = try loadDocumentIR(arguments: arguments)
            emit(Envelope(result: documentIRSummary(document)))
            return true

        case "ir-export-text":
            let document = try loadDocumentIR(arguments: arguments)
            let output = URL(fileURLWithPath: try arguments.value("--output"))
            let data = Data(document.plainText.utf8)
            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: output, options: .atomic)
            emit(Envelope(result: SaveResult(output: output.path, bytes: data.count)))
            return true

        default:
            return false
        }
    }

    private static func loadDocumentIR(arguments: Arguments) throws -> DocumentIR {
        let input = URL(fileURLWithPath: try arguments.value("--input"))
        let attributes = try FileManager.default.attributesOfItem(atPath: input.path)
        let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard bytes <= 256 * 1_024 * 1_024 else { throw CLIError.inputTooLarge(bytes) }
        do {
            return try DocumentIRCodec.decodeAndValidate(
                Data(contentsOf: input, options: [.mappedIfSafe])
            )
        } catch let error as CLIError {
            throw error
        } catch {
            throw CLIError.invalidDocumentIR(localizedMessage(error))
        }
    }

    private static func documentIRSummary(_ document: DocumentIR) -> DocumentIRSummaryResult {
        let blocks = document.pages.flatMap(\.blocks)
        return DocumentIRSummaryResult(
            protocolVersion: protocolVersion,
            schemaVersion: document.schemaVersion,
            providerID: document.provenance.providerID,
            modelID: document.provenance.modelID,
            pageCount: document.pages.count,
            blockCount: blocks.count,
            wordCount: blocks.flatMap(\.lines).flatMap(\.words).count,
            tableCount: blocks.filter { $0.kind == .table }.count,
            formulaCount: blocks.filter { $0.kind == .formula }.count,
            figureCount: blocks.filter { $0.kind == .figure }.count,
            plainTextCharacters: document.plainText.count
        )
    }

    private static func loadDocument(
        arguments: Arguments,
        engine: MuPDFDocumentEngine
    ) throws -> MuPDFDocument {
        let url = URL(fileURLWithPath: try arguments.value("--document"))
        return try engine.load(data: Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    private static func decodeAnnotation(arguments: Arguments) throws -> PDFAnnotationDescriptor {
        let payload = try arguments.value("--payload")
        do {
            return try JSONDecoder().decode(PDFAnnotationDescriptor.self, from: Data(payload.utf8))
        } catch {
            throw CLIError.invalidPayload(error.localizedDescription)
        }
    }

    private static func imageFormat(_ explicit: String?, imagePath: String?) throws -> PDFImageFormat {
        let raw = explicit ?? imagePath.map { URL(fileURLWithPath: $0).pathExtension.lowercased() } ?? "png"
        switch raw.lowercased() {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        default: throw CLIError.invalidArgument("--format", raw)
        }
    }

    private static func save(
        document: MuPDFDocument,
        output: String,
        engine: MuPDFDocumentEngine
    ) throws -> SaveResult {
        let destination = URL(fileURLWithPath: output)
        let data = try engine.dataRepresentation(of: document)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
        return SaveResult(output: destination.path, bytes: data.count)
    }
}

private struct Arguments {
    let command: String
    private let values: [String]

    init(_ raw: [String]) throws {
        guard raw.count >= 2 else { throw CLIError.missingCommand }
        command = raw[1]
        values = Array(raw.dropFirst(2))
    }

    func value(_ name: String) throws -> String {
        guard let index = values.firstIndex(of: name), values.indices.contains(index + 1) else {
            throw CLIError.missingArgument(name)
        }
        return values[index + 1]
    }

    func optional(_ name: String) -> String? {
        guard let index = values.firstIndex(of: name), values.indices.contains(index + 1) else { return nil }
        return values[index + 1]
    }

    func contains(_ name: String) -> Bool {
        values.contains(name)
    }

    func integer(_ name: String, minimum: Int) throws -> Int {
        let raw = try value(name)
        guard let result = Int(raw), result >= minimum else { throw CLIError.invalidArgument(name, raw) }
        return result
    }

    func double(_ name: String, minimum: Double, defaultValue: Double) throws -> Double {
        guard let raw = optional(name) else { return defaultValue }
        guard let result = Double(raw), result >= minimum else { throw CLIError.invalidArgument(name, raw) }
        return result
    }
}

private enum OCRRuntimeLocator {
    static func locate(explicitPath: String?) throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let candidates: [String?] = [
            explicitPath,
            environment["AZPDF_OCRMYPDF"],
            executableDirectory.appendingPathComponent(executableFileName).path,
            executableDirectory.appendingPathComponent("ocrmypdf").appendingPathComponent(executableFileName).path,
            executableDirectory.appendingPathComponent("runtime").appendingPathComponent("ocrmypdf").appendingPathComponent(executableFileName).path
        ]
        for candidate in candidates.compactMap({ $0 })
        where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        for directory in (environment["PATH"] ?? "").split(separator: pathSeparator) {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(executableFileName)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        throw CLIError.ocrRuntimeUnavailable
    }

    private static var executableFileName: String {
        #if os(Windows)
        "ocrmypdf.exe"
        #else
        "ocrmypdf"
        #endif
    }

    private static var pathSeparator: Character {
        #if os(Windows)
        ";"
        #else
        ":"
        #endif
    }
}

private enum PyHankoRuntimeLocator {
    static func locate(explicitPath: String?) throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let candidates: [String?] = [
            explicitPath,
            environment["AZPDF_PYHANKO"],
            executableDirectory.appendingPathComponent(executableFileName).path,
            executableDirectory.appendingPathComponent("pyhanko").appendingPathComponent(executableFileName).path,
            executableDirectory.appendingPathComponent("runtime").appendingPathComponent("pyhanko").appendingPathComponent(executableFileName).path
        ]
        for candidate in candidates.compactMap({ $0 })
        where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        for directory in (environment["PATH"] ?? "").split(separator: pathSeparator) {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(executableFileName)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        throw CLIError.signatureRuntimeUnavailable
    }

    private static var executableFileName: String {
        #if os(Windows)
        "pyhanko.exe"
        #else
        "pyhanko"
        #endif
    }

    private static var pathSeparator: Character {
        #if os(Windows)
        ";"
        #else
        ":"
        #endif
    }
}

private enum MuPDFRuntimeLocator {
    static func locate(explicitPath: String?) throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let executableName = executableFileName
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidates: [String?] = [
            explicitPath,
            environment["AZPDF_MUTOOL"],
            executableDirectory.appendingPathComponent(executableName).path,
            executableDirectory.appendingPathComponent("runtime").appendingPathComponent(executableName).path,
            executableDirectory.deletingLastPathComponent().appendingPathComponent("Resources").appendingPathComponent(executableName).path
        ]

        for candidate in candidates.compactMap({ $0 }) where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        for directory in (environment["PATH"] ?? "").split(separator: pathSeparator) {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(executableName)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        throw CLIError.runtimeUnavailable
    }

    private static var executableFileName: String {
        #if os(Windows)
        "mutool.exe"
        #else
        "mutool"
        #endif
    }

    private static var pathSeparator: Character {
        #if os(Windows)
        ";"
        #else
        ":"
        #endif
    }
}

private struct Envelope<Result: Encodable>: Encodable {
    let ok = true
    let result: Result
}

private struct FailureEnvelope: Encodable {
    let ok = false
    let error: ErrorPayload
}

private struct ErrorPayload: Encodable {
    let code: String
    let message: String
}

private struct HealthResult: Encodable {
    let protocolVersion: Int
    let engine: String
    let engineVersion: String
    let executable: String
}

private struct DocumentInfoResult: Encodable {
    let protocolVersion: Int
    let pageCount: Int
    let metadata: PDFDocumentMetadata
    let capabilities: [String]
}

private struct RenderResult: Encodable {
    let page: Int
    let width: Double
    let height: Double
    let format: String
    let output: String
    let pageBox: PDFRect
    let rotation: Int
}

private struct TextResult: Encodable {
    let page: Int
    let text: String
}

private struct SearchResult: Encodable {
    let query: String
    let matches: [PDFSearchMatch]
}

private struct AnnotationListResult: Encodable {
    let page: Int
    let annotations: [PDFAnnotationDescriptor]
}

private struct SaveResult: Encodable {
    let output: String
    let bytes: Int
}

private struct DocumentIRSummaryResult: Encodable {
    let protocolVersion: Int
    let schemaVersion: Int
    let providerID: String
    let modelID: String?
    let pageCount: Int
    let blockCount: Int
    let wordCount: Int
    let tableCount: Int
    let formulaCount: Int
    let figureCount: Int
    let plainTextCharacters: Int
}

private struct DocumentIRWriteResult: Encodable {
    let output: String
    let bytes: Int
    let summary: DocumentIRSummaryResult
}

private struct OCRCommandResult: Encodable {
    let provider: String
    let version: String
    let language: String
    let output: String
    let bytes: Int
    let features: [PDFOCRFeature]

    init(_ result: PDFOCRResult) {
        provider = result.provider
        version = result.version
        language = result.language
        output = result.output.path
        bytes = result.bytes
        features = result.features
    }
}

private struct SignatureCommandResult: Encodable {
    let provider: String
    let version: String
    let profile: PDFSignatureProfile
    let output: String
    let bytes: Int
    let verification: PDFSignatureVerification

    init(_ result: PDFSignatureResult) {
        provider = result.provider
        version = result.version
        profile = result.profile
        output = result.output.path
        bytes = result.bytes
        verification = result.verification
    }
}

private enum CLIError: LocalizedError {
    case missingCommand
    case invalidCommand(String)
    case missingArgument(String)
    case invalidArgument(String, String)
    case invalidPayload(String)
    case invalidDocumentIR(String)
    case inputTooLarge(Int)
    case runtimeUnavailable
    case ocrRuntimeUnavailable
    case invalidOCROutput
    case signatureRuntimeUnavailable
    case invalidSignatureOutput
    case engineFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            "Thiếu lệnh. Dùng: health, ir-baseline, ir-validate, ir-export-text, ocr-health, signature-health, info, page, render, text, search, annotations, upsert-annotation, upsert-image-annotation, remove-annotation, ocr, verify-signatures, sign-pades hoặc save-as."
        case let .invalidCommand(command):
            "Lệnh không được hỗ trợ: \(command)."
        case let .missingArgument(name):
            "Thiếu tham số bắt buộc \(name)."
        case let .invalidArgument(name, value):
            "Giá trị không hợp lệ cho \(name): \(value)."
        case let .invalidPayload(message):
            "Payload annotation không hợp lệ: \(message)"
        case let .invalidDocumentIR(message):
            "DocumentIR không hợp lệ: \(message)"
        case let .inputTooLarge(bytes):
            "DocumentIR vượt giới hạn 256 MiB: \(bytes) byte."
        case .runtimeUnavailable:
            "Không tìm thấy mutool. Đặt AZPDF_MUTOOL hoặc dùng --mutool /path/to/mutool."
        case .ocrRuntimeUnavailable:
            "Không tìm thấy OCRmyPDF. Đặt AZPDF_OCRMYPDF hoặc đóng gói runtime OCR cạnh azpdf-engine."
        case .invalidOCROutput:
            "PDF sau OCR không giữ nguyên số trang của tài liệu nguồn."
        case .signatureRuntimeUnavailable:
            "Không tìm thấy pyHanko. Đặt AZPDF_PYHANKO hoặc đóng gói runtime PAdES cạnh azpdf-engine."
        case .invalidSignatureOutput:
            "PDF sau khi ký không giữ nguyên số trang của tài liệu nguồn."
        case let .engineFailure(message):
            "MuPDF không khởi động được: \(message)."
        }
    }
}

private func capabilityNames(_ capabilities: PDFEngineCapabilities) -> [String] {
    let values: [(PDFEngineCapabilities, String)] = [
        (.open, "open"), (.save, "save"), (.render, "render"),
        (.extractText, "extractText"), (.search, "search"), (.metadata, "metadata"),
        (.annotations, "annotations"), (.forms, "forms"), (.pageEditing, "pageEditing"),
        (.redaction, "redaction"), (.encryption, "encryption"),
        (.digitalSignatures, "digitalSignatures"), (.outline, "outline"),
        (.embeddedFiles, "embeddedFiles"), (.structuredText, "structuredText")
    ]
    return values.compactMap { capabilities.contains($0.0) ? $0.1 : nil }
}

private func emit<Value: Encodable>(_ value: Value) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = (try? encoder.encode(value)) ?? Data(#"{"ok":false,"error":{"code":"encoding","message":"Không thể mã hóa phản hồi."}}"#.utf8)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
}

private func errorCode(_ error: Error) -> String {
    switch error {
    case CLIError.runtimeUnavailable: "runtime_unavailable"
    case CLIError.ocrRuntimeUnavailable: "ocr_unavailable"
    case CLIError.invalidOCROutput: "invalid_ocr_output"
    case CLIError.signatureRuntimeUnavailable: "signature_unavailable"
    case CLIError.invalidSignatureOutput: "invalid_signature_output"
    case CLIError.invalidDocumentIR: "invalid_document_ir"
    case CLIError.inputTooLarge: "input_too_large"
    case PyHankoSignatureError.invalidRequest, PyHankoSignatureError.insecurePasswordFile: "invalid_request"
    case is PyHankoSignatureError: "signature_error"
    case CLIError.missingCommand, CLIError.invalidCommand, CLIError.missingArgument, CLIError.invalidArgument, CLIError.invalidPayload: "invalid_request"
    case PDFEngineError.invalidDocument: "invalid_document"
    case PDFEngineError.invalidPageIndex: "invalid_page"
    case PDFEngineError.operationNotSupported: "unsupported_operation"
    default: "engine_error"
    }
}

private func localizedMessage(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
}

private func terminate(_ code: Int32) -> Never {
    #if canImport(WinSDK)
    ExitProcess(UInt32(bitPattern: code))
    fatalError("ExitProcess returned unexpectedly")
    #else
    exit(code)
    #endif
}
