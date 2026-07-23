import AppKit
import PDFKit

// Printing goes through PDFDocument.printOperation, not PlacementPDFView's
// readerAction chain: that chain is wired to undo/redraw (registerUndoStep in
// sendReaderAction) and printing isn't an edit. The store already holds the
// PDFDocument, so it builds the operation directly — see
// .forge/2026-07-23-in-an-print/plan.md for the full comparison.
extension DocumentStore {
    /// Builds a configured NSPrintOperation without running it, so callers (and
    /// tests) can inspect or run it headless before any panel appears. A fresh
    /// NSPrintInfo() per call — never NSPrintInfo.shared — keeps tests from
    /// leaking print state globally.
    func makePrintOperation() -> NSPrintOperation? {
        guard let document else { return nil }
        let operation = document.printOperation(
            for: NSPrintInfo(),
            scalingMode: .pageScaleDownToFit,
            autoRotate: true
        )
        operation?.jobTitle = title
        return operation
    }

    @MainActor
    func printDocument() {
        guard let operation = makePrintOperation() else { return }
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}
