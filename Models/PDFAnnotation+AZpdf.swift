import PDFKit

extension PDFAnnotation {
    /// PDFKit exposes subtype constants with a leading slash while annotations
    /// read from a page may omit it. Normalize both forms before comparison.
    var azpdfSubtype: String {
        (type ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }

    var isAZpdfFreeText: Bool { azpdfSubtype == "freetext" }
    var isAZpdfNote: Bool { azpdfSubtype == "text" }
    var isAZpdfImage: Bool { azpdfSubtype == "stamp" }
    var isAZpdfPopup: Bool { azpdfSubtype == "popup" }
    var isAZpdfMovable: Bool { ["freetext", "ink", "stamp", "text"].contains(azpdfSubtype) }
}
