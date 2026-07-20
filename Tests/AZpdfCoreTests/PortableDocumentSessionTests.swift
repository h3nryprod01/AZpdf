import Foundation
import XCTest
@testable import AZpdfCore

final class PortableDocumentSessionTests: XCTestCase {
    func testApplyUndoRedoAndSaveState() throws {
        let engine = FakeDocumentEngine()
        let session = try PortableDocumentSession(data: engine.data(for: [0, 0]), engine: engine)

        try session.apply(.rotate(page: 0))
        XCTAssertTrue(session.isModified)
        XCTAssertTrue(session.canUndo)
        XCTAssertEqual(session.document.rotations, [90, 0])

        try session.undo()
        XCTAssertEqual(session.document.rotations, [0, 0])
        XCTAssertTrue(session.canRedo)
        XCTAssertFalse(session.isModified)

        try session.redo()
        XCTAssertEqual(session.document.rotations, [90, 0])
        try session.markSaved()
        XCTAssertFalse(session.isModified)
    }

    func testFailedOperationRollsBackDocument() throws {
        let engine = FakeDocumentEngine()
        let session = try PortableDocumentSession(data: engine.data(for: [0]), engine: engine)

        XCTAssertThrowsError(try session.apply(.delete(page: 3)))
        XCTAssertEqual(session.document.rotations, [0])
        XCTAssertFalse(session.canUndo)
        XCTAssertFalse(session.isModified)
    }

    func testHistoryLimitDropsOldestSnapshot() throws {
        let engine = FakeDocumentEngine()
        let session = try PortableDocumentSession(
            data: engine.data(for: [0]),
            engine: engine,
            historyLimit: 2
        )

        try session.apply(.rotate(page: 0))
        try session.apply(.rotate(page: 0))
        try session.apply(.rotate(page: 0))
        try session.undo()
        try session.undo()
        try session.undo()

        XCTAssertEqual(session.document.rotations, [90])
        XCTAssertFalse(session.canUndo)
    }

    func testPageDescriptorNormalizesRotation() {
        let descriptor = PDFPageDescriptor(
            index: 0,
            mediaBox: PDFRect(x: 0, y: 0, width: 595, height: 842),
            cropBox: PDFRect(x: 0, y: 0, width: 595, height: 842),
            rotation: -90
        )
        XCTAssertEqual(descriptor.rotation, 270)
    }
}

private final class FakeDocument {
    var rotations: [Int]

    init(rotations: [Int]) {
        self.rotations = rotations
    }
}

private struct FakeDocumentEngine: PDFDocumentEngine {
    let capabilities: PDFEngineCapabilities = [.open, .save, .pageEditing]

    func data(for rotations: [Int]) throws -> Data {
        try JSONEncoder().encode(rotations)
    }

    func load(data: Data) throws -> FakeDocument {
        FakeDocument(rotations: try JSONDecoder().decode([Int].self, from: data))
    }

    func dataRepresentation(of document: FakeDocument) throws -> Data {
        try data(for: document.rotations)
    }

    func pageCount(of document: FakeDocument) -> Int {
        document.rotations.count
    }

    func apply(_ operation: DocumentOperation, to document: FakeDocument) throws {
        switch operation {
        case let .rotate(page):
            guard document.rotations.indices.contains(page) else { throw PDFEngineError.invalidPageIndex }
            document.rotations[page] = (document.rotations[page] + 90) % 360
        case let .duplicate(page):
            guard document.rotations.indices.contains(page) else { throw PDFEngineError.invalidPageIndex }
            document.rotations.insert(document.rotations[page], at: page + 1)
        case let .delete(page):
            guard document.rotations.indices.contains(page) else { throw PDFEngineError.invalidPageIndex }
            document.rotations.remove(at: page)
        default:
            throw PDFEngineError.operationNotSupported
        }
    }
}
