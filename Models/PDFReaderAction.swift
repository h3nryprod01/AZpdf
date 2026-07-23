import Foundation

enum PDFReaderAction: Equatable {
    case none
    case addNote
    case highlightSelection
    case freeText(String)
    case signature([SignatureStroke])
    case image(URL)
    case shape(ShapeKind)
    case redactSelection
    case ocrRegion
}
