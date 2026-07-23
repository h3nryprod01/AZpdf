import AppKit
import PDFKit

/// The shape palette, mirroring Preview's Annotate submenu.
///
/// Every shape is a real PDF annotation subtype so other viewers render it
/// rather than showing a blank box: rectangle/oval/line/arrow map to
/// Square/Circle/Line, for which PDFKit writes an `/AP` appearance stream on
/// save. Star and triangle have no subtype of their own in the PDF spec, so
/// they are drawn as Ink paths — the same route the hand-drawn signature takes.
enum ShapeKind: String, CaseIterable, Identifiable {
    case rectangle
    case oval
    case line
    case arrow
    case star
    case triangle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rectangle: "Chữ nhật"
        case .oval: "Hình tròn"
        case .line: "Đường kẻ"
        case .arrow: "Mũi tên"
        case .star: "Ngôi sao"
        case .triangle: "Tam giác"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: "rectangle"
        case .oval: "circle"
        case .line: "line.diagonal"
        case .arrow: "line.diagonal.arrow"
        case .star: "star"
        case .triangle: "triangle"
        }
    }

    /// Ink-drawn shapes carry a stroke but no interior fill, because `/InkList`
    /// has no fill colour — the popover hides the fill control for them.
    var isInkDrawn: Bool { self == .star || self == .triangle }

    /// A line is a stroke between two points; there is nothing to fill.
    var supportsFill: Bool { self == .rectangle || self == .oval }

    var subtype: PDFAnnotationSubtype {
        switch self {
        case .rectangle: .square
        case .oval: .circle
        case .line, .arrow: .line
        case .star, .triangle: .ink
        }
    }
}

enum ShapeAnnotationFactory {
    /// Written into `/T`, so the shape stays identifiable after the file is
    /// closed and reopened — without it a reopened star is just an anonymous
    /// ink blob that resize would silently mangle.
    static let userNamePrefix = "AZpdf Shape "

    static func make(
        _ kind: ShapeKind,
        bounds: CGRect,
        stroke: NSColor,
        fill: NSColor?,
        lineWidth: CGFloat
    ) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: kind.subtype, withProperties: nil)
        annotation.userName = userNamePrefix + kind.rawValue
        annotation.contents = kind.label
        annotation.color = stroke
        if kind.supportsFill { annotation.interiorColor = fill }
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border
        if kind == .arrow { annotation.endLineStyle = .closedArrow }
        applyGeometry(to: annotation, kind: kind)
        return annotation
    }

    /// Rewrites the geometry that does *not* follow `bounds` on its own.
    /// Square and Circle draw themselves into `/Rect`, so resizing them is
    /// enough; a Line's endpoints and an Ink shape's paths are stored
    /// separately and go stale on every resize, leaving the frame in the new
    /// place and the shape in the old one.
    static func applyGeometry(to annotation: PDFAnnotation, kind: ShapeKind) {
        let size = annotation.bounds.size
        switch kind {
        case .rectangle, .oval:
            return
        case .line, .arrow:
            // Local to the bounds origin, not page space: PDFKit adds
            // bounds.origin itself when writing `/L` (verified against the
            // written bytes — the same convention that broke the signature's
            // `/InkList`, see PDFReaderView.signaturePoint).
            annotation.startPoint = CGPoint(x: 0, y: 0)
            annotation.endPoint = CGPoint(x: size.width, y: size.height)
        case .star, .triangle:
            for path in annotation.paths ?? [] { annotation.remove(path) }
            let points = kind == .star ? starPoints(in: size) : trianglePoints(in: size)
            annotation.add(closedPath(through: points))
        }
    }

    /// Vertices of a five-pointed star filling `size`, first point at top
    /// centre, alternating outer and inner radius. `innerRatio` is the classic
    /// pentagram ratio, which is what makes it read as a star rather than a
    /// spiky blob.
    static func starPoints(in size: CGSize, points: Int = 5, innerRatio: CGFloat = 0.382) -> [CGPoint] {
        let raw = (0..<(points * 2)).map { index -> CGPoint in
            let radius = index.isMultiple(of: 2) ? CGFloat(1) : innerRatio
            let angle = CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / CGFloat(points)
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        return fit(raw, in: size)
    }

    static func trianglePoints(in size: CGSize) -> [CGPoint] {
        [CGPoint(x: size.width / 2, y: size.height),
         CGPoint(x: 0, y: 0),
         CGPoint(x: size.width, y: 0)]
    }

    /// Scales vertices so their bounding box exactly fills `size`.
    ///
    /// A star's vertices touch its circumscribed circle at only five angles, so
    /// laying them out on that circle leaves a visible margin — 5% at the sides
    /// and 19% at the bottom. The shape would then not follow the frame the
    /// user just dragged, which reads as a broken resize.
    private static func fit(_ points: [CGPoint], in size: CGSize) -> [CGPoint] {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max(),
              maxX > minX, maxY > minY else { return points }
        return points.map {
            CGPoint(x: ($0.x - minX) / (maxX - minX) * size.width,
                    y: ($0.y - minY) / (maxY - minY) * size.height)
        }
    }

    private static func closedPath(through points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        // `/InkList` has no close-path operator, so the outline is closed by
        // repeating the first vertex.
        path.line(to: first)
        return path
    }
}

extension PDFAnnotation {
    /// The shape this annotation was created as, or nil if it is not an AZpdf
    /// shape at all.
    var azpdfShapeKind: ShapeKind? {
        guard let userName, userName.hasPrefix(ShapeAnnotationFactory.userNamePrefix) else { return nil }
        return ShapeKind(rawValue: String(userName.dropFirst(ShapeAnnotationFactory.userNamePrefix.count)))
    }

    /// Rebuilds line endpoints / ink paths after `bounds` changed. A no-op for
    /// every other annotation, so resize paths can call it unconditionally.
    func refreshAZpdfShapeGeometry() {
        guard let kind = azpdfShapeKind else { return }
        ShapeAnnotationFactory.applyGeometry(to: self, kind: kind)
    }
}
