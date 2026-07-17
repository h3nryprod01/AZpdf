import AppKit
import PDFKit

/// A session-editable image annotation. A portable export can flatten it later,
/// while the open document stays selectable, movable and resizable.
final class EditableImageAnnotation: PDFAnnotation {
    private var image: NSImage

    init(image: NSImage, bounds: CGRect) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
        contents = "Ảnh chèn bởi AZpdf"
        color = .clear
    }

    required init?(coder: NSCoder) {
        guard let decodedImage = coder.decodeObject(of: NSImage.self, forKey: "AZpdfImage") else { return nil }
        image = decodedImage
        super.init(coder: coder)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(image, forKey: "AZpdfImage")
    }

    func replaceImage(_ image: NSImage) {
        self.image = image
        modificationDate = Date()
    }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        context.saveGState()
        context.interpolationQuality = .high
        context.draw(cgImage, in: bounds)
        context.restoreGState()
    }
}
