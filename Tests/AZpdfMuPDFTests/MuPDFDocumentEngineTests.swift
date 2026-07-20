import Foundation
import XCTest
import AZpdfCore
@testable import AZpdfMuPDF

final class MuPDFDocumentEngineTests: XCTestCase {
    func testPrototypeLoadsReadsAndRendersThroughRunner() throws {
        let runner = MockMuPDFRunner()
        let engine = MuPDFDocumentEngine(
            executableURL: URL(fileURLWithPath: "/usr/bin/mutool"),
            runner: runner
        )
        let document = try engine.load(data: Data("%PDF-mock".utf8))

        let page = try engine.pageDescriptor(at: 0, in: document)
        let text = try engine.text(ofPage: 0, in: document)
        let render = try engine.render(PDFRenderRequest(pageIndex: 0, scale: 2), in: document)
        let metadata = try engine.metadata(of: document)
        let layout = try engine.structuredText(ofPage: 0, in: document)

        XCTAssertEqual(engine.pageCount(of: document), 1)
        XCTAssertEqual(page.cropBox.size, PDFSize(width: 595, height: 842))
        XCTAssertEqual(text, "AZpdf fixture")
        XCTAssertEqual(render.size, PDFSize(width: 1190, height: 1684))
        XCTAssertEqual(render.pageBox.size, PDFSize(width: 595, height: 842))
        XCTAssertEqual(render.rotation, 0)
        XCTAssertEqual(render.data, Data([0x89, 0x50, 0x4E, 0x47]))
        XCTAssertEqual(metadata.title, "Fixture")
        XCTAssertEqual(metadata.author, "AZpdf")
        XCTAssertEqual(layout.coordinateSpace, .pageTopLeft)
        XCTAssertEqual(layout.blocks.first?.lines.first?.text, "AZpdf fixture")
    }

    func testPrototypeReportsRotatedRenderGeometry() throws {
        let engine = MuPDFDocumentEngine(
            executableURL: URL(fileURLWithPath: "/usr/bin/mutool"),
            runner: MockMuPDFRunner(rotation: 90)
        )
        let document = try engine.load(data: Data("%PDF-mock".utf8))

        let render = try engine.render(PDFRenderRequest(pageIndex: 0), in: document)

        XCTAssertEqual(render.pageBox.size, PDFSize(width: 595, height: 842))
        XCTAssertEqual(render.rotation, 90)
        XCTAssertEqual(render.size, PDFSize(width: 842, height: 595))
    }

    func testPrototypeRejectsInvalidPage() throws {
        let engine = MuPDFDocumentEngine(
            executableURL: URL(fileURLWithPath: "/usr/bin/mutool"),
            runner: MockMuPDFRunner()
        )
        let document = try engine.load(data: Data("%PDF-mock".utf8))

        XCTAssertThrowsError(try engine.text(ofPage: 2, in: document)) { error in
            XCTAssertEqual(error as? PDFEngineError, .invalidPageIndex)
        }
    }

    func testPrototypeAdvertisesEditableAnnotationsButNotPageEditing() {
        let engine = MuPDFDocumentEngine(
            executableURL: URL(fileURLWithPath: "/usr/bin/mutool"),
            runner: MockMuPDFRunner()
        )
        XCTAssertTrue(engine.capabilities.contains(.annotations))
        XCTAssertFalse(engine.capabilities.contains(.pageEditing))
    }

    func testPrototypeUpsertsListsAndRemovesEditableAnnotation() throws {
        let engine = MuPDFDocumentEngine(
            executableURL: URL(fileURLWithPath: "/usr/bin/mutool"),
            runner: MockMuPDFRunner()
        )
        let document = try engine.load(data: Data("%PDF-mock".utf8))
        let descriptor = PDFAnnotationDescriptor(
            id: "text-1",
            kind: .freeText,
            pageIndex: 0,
            bounds: PDFRect(x: 40, y: 60, width: 180, height: 48),
            contents: "Editable text",
            textStyle: PDFTextStyle(fontSize: 18, isBold: true)
        )

        try engine.apply(.upsertAnnotation(descriptor), to: document)
        let annotations = try engine.annotations(onPage: 0, in: document)
        XCTAssertEqual(annotations.first?.id, "text-1")
        XCTAssertEqual(annotations.first?.textStyle?.fontSize, 18)
        XCTAssertEqual(annotations.first?.coordinateSpace, .pdfBottomLeft)
        try engine.apply(.removeAnnotation(id: descriptor.id, page: 0), to: document)
    }

    func testInstalledMuPDFAgainstGeneratedFixture() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let executable = environment["AZPDF_MUTOOL"],
              let fixture = environment["AZPDF_MUPDF_FIXTURE"]
        else {
            throw XCTSkip("Set AZPDF_MUTOOL and AZPDF_MUPDF_FIXTURE to run the real MuPDF integration test.")
        }
        let engine = MuPDFDocumentEngine(executableURL: URL(fileURLWithPath: executable))
        let document = try engine.load(data: Data(contentsOf: URL(fileURLWithPath: fixture)))

        XCTAssertEqual(engine.pageCount(of: document), 1)
        XCTAssertTrue(try engine.text(ofPage: 0, in: document).contains("AZpdf engine fixture"))
        let renderedPNG = try engine.render(PDFRenderRequest(pageIndex: 0), in: document).data
        XCTAssertFalse(renderedPNG.isEmpty)
        XCTAssertEqual(try engine.pageDescriptor(at: 0, in: document).rotation, 0)
        let layout = try engine.structuredText(ofPage: 0, in: document)
        XCTAssertTrue(layout.blocks.flatMap(\.lines).contains { $0.text.contains("AZpdf engine fixture") })

        let freeText = PDFAnnotationDescriptor(
            id: "integration-text",
            kind: .freeText,
            pageIndex: 0,
            bounds: PDFRect(x: 80, y: 620, width: 240, height: 60),
            contents: "AZpdf editable text",
            textStyle: PDFTextStyle(fontSize: 20, alignment: .center, isBold: true)
        )
        try engine.apply(.upsertAnnotation(freeText), to: document)
        var annotations = try engine.annotations(onPage: 0, in: document)
        let insertedText = try XCTUnwrap(annotations.first(where: { $0.id == freeText.id }))
        XCTAssertEqual(insertedText.contents, freeText.contents)
        XCTAssertEqual(insertedText.textStyle?.fontSize, 20)
        XCTAssertEqual(insertedText.textStyle?.alignment, .center)
        XCTAssertEqual(insertedText.textStyle?.isBold, true)

        var movedText = freeText
        movedText.bounds = PDFRect(x: 120, y: 560, width: 300, height: 72)
        movedText.contents = "AZpdf moved and formatted text"
        movedText.textStyle = PDFTextStyle(
            fontSize: 24,
            color: PDFColor(red: 0.05, green: 0.37, blue: 0.72),
            alignment: .right,
            isItalic: true
        )
        try engine.apply(.upsertAnnotation(movedText), to: document)

        var note = PDFAnnotationDescriptor(
            id: "integration-note",
            kind: .note,
            pageIndex: 0,
            bounds: PDFRect(x: 48, y: 520, width: 20, height: 20),
            contents: "AZpdf editable note",
            color: PDFColor(red: 1, green: 0.82, blue: 0)
        )
        try engine.apply(.upsertAnnotation(note), to: document)
        note.bounds = PDFRect(x: 92, y: 500, width: 20, height: 20)
        note.contents = "AZpdf moved note"
        try engine.apply(.upsertAnnotation(note), to: document)

        var image = PDFAnnotationDescriptor(
            id: "integration-image",
            kind: .image,
            pageIndex: 0,
            bounds: PDFRect(x: 360, y: 520, width: 120, height: 90)
        )
        try engine.apply(.upsertImageAnnotation(image, imageData: renderedPNG, format: .png), to: document)
        image.bounds = PDFRect(x: 340, y: 480, width: 160, height: 120)
        try engine.apply(.upsertImageAnnotation(image, imageData: nil, format: .png), to: document)

        annotations = try engine.annotations(onPage: 0, in: document)
        let editedText = try XCTUnwrap(annotations.first(where: { $0.id == movedText.id }))
        XCTAssertEqual(editedText.contents, movedText.contents)
        XCTAssertEqual(editedText.textStyle?.fontSize, 24)
        XCTAssertEqual(editedText.textStyle?.alignment, .right)
        XCTAssertEqual(editedText.textStyle?.isItalic, true)
        XCTAssertEqual(editedText.textStyle?.color.red ?? -1, 0.05, accuracy: 0.001)
        XCTAssertEqual(editedText.textStyle?.color.green ?? -1, 0.37, accuracy: 0.001)
        XCTAssertEqual(editedText.textStyle?.color.blue ?? -1, 0.72, accuracy: 0.001)
        assertBounds(editedText.bounds, equalTo: movedText.bounds)

        let editedNote = try XCTUnwrap(annotations.first(where: { $0.id == note.id }))
        XCTAssertEqual(editedNote.contents, note.contents)
        assertBounds(editedNote.bounds, equalTo: note.bounds)

        let editedImage = try XCTUnwrap(annotations.first(where: { $0.id == image.id }))
        XCTAssertEqual(editedImage.kind, .image)
        assertBounds(editedImage.bounds, equalTo: image.bounds)

        XCTAssertFalse(try engine.render(PDFRenderRequest(pageIndex: 0), in: document).data.isEmpty)

        try engine.apply(.removeAnnotation(id: movedText.id, page: 0), to: document)
        try engine.apply(.removeAnnotation(id: note.id, page: 0), to: document)
        try engine.apply(.removeAnnotation(id: image.id, page: 0), to: document)
        XCTAssertTrue(try engine.annotations(onPage: 0, in: document).allSatisfy {
            ![movedText.id, note.id, image.id].contains($0.id)
        })
    }

    func testSubprocessRunnerTerminatesTimedOutProcess() {
        let runner = SubprocessMuPDFCommandRunner(timeout: 0.1)
        #if os(Windows)
        let executable = URL(fileURLWithPath: "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe")
        let arguments = ["-NoProfile", "-NonInteractive", "-Command", "Start-Sleep -Seconds 2"]
        #else
        let executable = URL(fileURLWithPath: "/bin/sleep")
        let arguments = ["2"]
        #endif
        XCTAssertThrowsError(try runner.run(
            executable: executable,
            arguments: arguments
        )) { error in
            guard case let PDFEngineError.ioFailure(message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(message.contains("timeout"))
        }
    }

    func testOCRmyPDFProcessorReportsCapabilitiesAndCreatesOutput() throws {
        let runner = MockOCRRunner()
        let processor = OCRmyPDFProcessor(
            executableURL: URL(fileURLWithPath: "/usr/bin/ocrmypdf"),
            runner: runner
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AZpdf-OCR-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("input.pdf")
        let output = directory.appendingPathComponent("output.pdf")
        try Data("%PDF-input".utf8).write(to: input)

        let capabilities = try processor.capabilities()
        let result = try processor.process(
            PDFOCRRequest(language: "vie+eng", deskew: true, rotatePages: true),
            input: input,
            output: output
        )

        XCTAssertEqual(capabilities.provider, "OCRmyPDF")
        XCTAssertEqual(capabilities.version, "17.8.1")
        XCTAssertEqual(capabilities.features, [.searchablePDF, .visualLayoutPreservation])
        XCTAssertEqual(result.language, "vie+eng")
        XCTAssertEqual(result.bytes, Data("%PDF-output".utf8).count)
        XCTAssertTrue(runner.lastOCRArguments.contains("--skip-text"))
        XCTAssertTrue(runner.lastOCRArguments.contains("--deskew"))
        XCTAssertTrue(runner.lastOCRArguments.contains("--rotate-pages"))
        XCTAssertEqual(Array(runner.lastOCRArguments.suffix(2)), [input.path, output.path])
    }

    func testOCRmyPDFProcessorRejectsUnsafeLanguageValue() throws {
        let processor = OCRmyPDFProcessor(
            executableURL: URL(fileURLWithPath: "/usr/bin/ocrmypdf"),
            runner: MockOCRRunner()
        )
        let directory = FileManager.default.temporaryDirectory
        XCTAssertThrowsError(try processor.process(
            PDFOCRRequest(language: "vie;curl"),
            input: directory.appendingPathComponent("input.pdf"),
            output: directory.appendingPathComponent("output.pdf")
        ))
    }

    private func assertBounds(
        _ actual: PDFRect,
        equalTo expected: PDFRect,
        accuracy: Double = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.size.width, expected.size.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.size.height, expected.size.height, accuracy: accuracy, file: file, line: line)
    }
}

private final class MockOCRRunner: MuPDFCommandRunning {
    private(set) var lastOCRArguments: [String] = []

    func run(executable: URL, arguments: [String]) throws -> MuPDFCommandResult {
        if arguments == ["--version"] {
            return MuPDFCommandResult(
                status: 0,
                standardOutput: Data("17.8.1\n".utf8)
            )
        }
        lastOCRArguments = arguments
        guard let output = arguments.last else { return MuPDFCommandResult(status: 2) }
        try Data("%PDF-output".utf8).write(to: URL(fileURLWithPath: output))
        return MuPDFCommandResult(status: 0)
    }
}

private final class MockMuPDFRunner: MuPDFCommandRunning {
    private let rotation: Int

    init(rotation: Int = 0) {
        self.rotation = rotation
    }

    func run(executable: URL, arguments: [String]) throws -> MuPDFCommandResult {
        switch arguments.first {
        case "pages":
            return .init(status: 0, standardOutput: Data("""
            mock.pdf:
            <page pagenum="1">
            <MediaBox l="0" b="0" r="595" t="842" />
            <Rotate v="\(rotation)" />
            </page>
            """.utf8))
        case "show":
            return .init(status: 0, standardOutput: Data("""
            <<
              /Title (Fixture)
              /Author (AZpdf)
            >>
            """.utf8))
        case "draw":
            guard let outputIndex = arguments.firstIndex(of: "-o"),
                  arguments.indices.contains(outputIndex + 1)
            else { return .init(status: 2) }
            let output = URL(fileURLWithPath: arguments[outputIndex + 1])
            if arguments.contains("stext.json") {
                try Data("""
                {"pages":[{"blocks":[{"type":"text","bbox":{"x":10,"y":20,"w":100,"h":16},"lines":[{"wmode":0,"bbox":{"x":10,"y":20,"w":100,"h":16},"font":{"name":"Helvetica","family":"sans-serif","size":12},"text":"AZpdf fixture"}]}]}]}
                """.utf8).write(to: output)
            } else if arguments.contains("txt") {
                try Data("AZpdf fixture".utf8).write(to: output)
            } else {
                try Data([0x89, 0x50, 0x4E, 0x47]).write(to: output)
            }
            return .init(status: 0)
        case "run":
            guard arguments.count >= 3 else { return .init(status: 2) }
            switch arguments[2] {
            case "list":
                let descriptor = PDFAnnotationDescriptor(
                    id: "text-1",
                    kind: .freeText,
                    pageIndex: 0,
                    bounds: PDFRect(x: 40, y: 60, width: 180, height: 48),
                    contents: "Editable text",
                    textStyle: PDFTextStyle(fontSize: 18, isBold: true)
                )
                return .init(status: 0, standardOutput: try JSONEncoder().encode([descriptor]))
            case "upsert", "remove":
                guard arguments.indices.contains(4) else { return .init(status: 2) }
                try Data("%PDF-mock".utf8).write(to: URL(fileURLWithPath: arguments[4]))
                return .init(status: 0)
            default:
                return .init(status: 2)
            }
        default:
            return .init(status: 2, standardError: Data("unsupported".utf8))
        }
    }
}
