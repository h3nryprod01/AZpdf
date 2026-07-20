import Foundation

/// Platform-neutral document lifecycle. UI layers own presentation state while
/// engines own parsing and persistence. Byte snapshots keep undo semantics equal
/// across PDFKit, MuPDF and future adapters.
public final class PortableDocumentSession<Engine: PDFDocumentEngine> {
    public let engine: Engine
    public private(set) var document: Engine.Document
    public private(set) var isModified = false
    public private(set) var canUndo = false
    public private(set) var canRedo = false

    private let historyLimit: Int
    private var undoStack: [Data] = []
    private var redoStack: [Data] = []
    private var savedRepresentation: Data

    public init(data: Data, engine: Engine, historyLimit: Int = 20) throws {
        self.engine = engine
        document = try engine.load(data: data)
        savedRepresentation = data
        self.historyLimit = max(1, historyLimit)
    }

    public var pageCount: Int { engine.pageCount(of: document) }
    public var capabilities: PDFEngineCapabilities { engine.capabilities }

    public func dataRepresentation() throws -> Data {
        try engine.dataRepresentation(of: document)
    }

    public func apply(_ operation: DocumentOperation) throws {
        let before = try dataRepresentation()
        do {
            try engine.apply(operation, to: document)
        } catch {
            document = try engine.load(data: before)
            throw error
        }
        append(before, to: &undoStack)
        redoStack.removeAll(keepingCapacity: true)
        refreshState()
    }

    public func undo() throws {
        guard let snapshot = undoStack.popLast() else { return }
        append(try dataRepresentation(), to: &redoStack)
        document = try engine.load(data: snapshot)
        refreshState()
    }

    public func redo() throws {
        guard let snapshot = redoStack.popLast() else { return }
        append(try dataRepresentation(), to: &undoStack)
        document = try engine.load(data: snapshot)
        refreshState()
    }

    /// Call only after the UI has successfully written the returned bytes.
    public func markSaved() throws {
        savedRepresentation = try dataRepresentation()
        refreshState()
    }

    public func replace(with data: Data, markAsSaved: Bool = true) throws {
        document = try engine.load(data: data)
        undoStack.removeAll(keepingCapacity: false)
        redoStack.removeAll(keepingCapacity: false)
        if markAsSaved { savedRepresentation = data }
        refreshState()
    }

    private func append(_ snapshot: Data, to stack: inout [Data]) {
        stack.append(snapshot)
        if stack.count > historyLimit { stack.removeFirst(stack.count - historyLimit) }
    }

    private func refreshState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        isModified = (try? dataRepresentation()) != savedRepresentation
    }
}
