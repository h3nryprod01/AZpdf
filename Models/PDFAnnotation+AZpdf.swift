import PDFKit

extension PDFAnnotation {
    /// PDFKit exposes subtype constants with a leading slash while annotations
    /// read from a page may omit it. Normalize both forms before comparison.
    var azpdfSubtype: String {
        (type ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }

    // `text` keeps notes created by versions before the editable note card.
    var isAZpdfNote: Bool { userName == "AZpdf Note" || azpdfSubtype == "text" }
    var isAZpdfFreeText: Bool { azpdfSubtype == "freetext" && !isAZpdfNote }
    var isAZpdfImage: Bool { azpdfSubtype == "stamp" }
    // Star and triangle are ink-drawn shapes, so they must not be mistaken for
    // a hand-drawn signature — the popover shows a different editor for each.
    var isAZpdfInk: Bool { azpdfSubtype == "ink" && !isAZpdfShape }
    var isAZpdfShape: Bool { azpdfShapeKind != nil }
    var isAZpdfPopup: Bool { azpdfSubtype == "popup" }
    var isAZpdfMovable: Bool { ["freetext", "ink", "stamp", "text"].contains(azpdfSubtype) || isAZpdfShape }
    // A note is a fixed-size icon: movable but not resizable.
    var isAZpdfResizable: Bool { isAZpdfFreeText || isAZpdfInk || isAZpdfImage || isAZpdfShape }
    /// Free-form types resize on each axis independently and lock aspect only
    /// while Shift is held; an image or signature does the opposite, because
    /// distorting either one is almost never what was meant.
    var isAZpdfFreeformResize: Bool { isAZpdfFreeText || isAZpdfShape }
}
