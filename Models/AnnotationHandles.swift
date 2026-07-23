import CoreGraphics

/// Selection-frame handle geometry and resize maths for a resizable
/// annotation. Pure struct, no PDFKit/AppKit/SwiftUI — the resize/aspect/clamp
/// maths is the error-prone part, so it lives here where it can be unit
/// tested without a GUI. Callers hit-test in view space (handles are a
/// constant screen size) and resize in page space (resolution-independent).
struct AnnotationHandles {
    enum Handle: CaseIterable, Hashable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

        var isCorner: Bool {
            switch self {
            case .topLeft, .topRight, .bottomRight, .bottomLeft: true
            case .top, .right, .bottom, .left: false
            }
        }
    }

    enum Hit: Equatable {
        case handle(Handle)
        case body
        case none
    }

    let rect: CGRect
    let handleSize: CGFloat

    /// Handle squares centred on the four corners, plus the four edge
    /// midpoints when `includeEdges` (free-text only — see `isAZpdfFreeText`).
    func handleRects(includeEdges: Bool) -> [Handle: CGRect] {
        let half = handleSize / 2
        func square(_ point: CGPoint) -> CGRect {
            CGRect(x: point.x - half, y: point.y - half, width: handleSize, height: handleSize)
        }
        var rects: [Handle: CGRect] = [
            .topLeft: square(CGPoint(x: rect.minX, y: rect.maxY)),
            .topRight: square(CGPoint(x: rect.maxX, y: rect.maxY)),
            .bottomRight: square(CGPoint(x: rect.maxX, y: rect.minY)),
            .bottomLeft: square(CGPoint(x: rect.minX, y: rect.minY))
        ]
        guard includeEdges else { return rects }
        rects[.top] = square(CGPoint(x: rect.midX, y: rect.maxY))
        rects[.right] = square(CGPoint(x: rect.maxX, y: rect.midY))
        rects[.bottom] = square(CGPoint(x: rect.midX, y: rect.minY))
        rects[.left] = square(CGPoint(x: rect.minX, y: rect.midY))
        return rects
    }

    /// Priority: a handle square wins over the body, the body wins over none.
    func hit(_ point: CGPoint, includeEdges: Bool) -> Hit {
        if let handle = handleRects(includeEdges: includeEdges).first(where: { $0.value.contains(point) })?.key {
            return .handle(handle)
        }
        return rect.contains(point) ? .body : .none
    }

    /// New bounds for a corner/edge drag, in page space. Corners anchor the
    /// opposite corner (aspect-locked scales both axes evenly, guarding a
    /// zero-size original; free varies both axes independently). Edges
    /// (free-text only) change one axis. Min size and the page crop box are
    /// enforced here so callers always receive an in-bounds rect.
    static func resizedBounds(
        original: CGRect,
        handle: Handle,
        to point: CGPoint,
        aspectLocked: Bool,
        minSize: CGSize,
        within pageBounds: CGRect
    ) -> CGRect {
        let resized = handle.isCorner
            ? resizedCorner(original: original, handle: handle, to: point, aspectLocked: aspectLocked)
            : resizedEdge(original: original, handle: handle, to: point)
        return clamp(resized, minSize: minSize, within: pageBounds)
    }

    private static func resizedCorner(original: CGRect, handle: Handle, to point: CGPoint, aspectLocked: Bool) -> CGRect {
        let anchor: CGPoint
        switch handle {
        case .topLeft: anchor = CGPoint(x: original.maxX, y: original.minY)
        case .topRight: anchor = CGPoint(x: original.minX, y: original.minY)
        case .bottomRight: anchor = CGPoint(x: original.minX, y: original.maxY)
        case .bottomLeft: anchor = CGPoint(x: original.maxX, y: original.maxY)
        default: anchor = original.origin // edges never reach here
        }
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        var width = abs(dx)
        var height = abs(dy)
        if aspectLocked, original.width > 0, original.height > 0 {
            let scale = max(width / original.width, height / original.height)
            width = original.width * scale
            height = original.height * scale
        }
        let x = dx < 0 ? anchor.x - width : anchor.x
        let y = dy < 0 ? anchor.y - height : anchor.y
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func resizedEdge(original: CGRect, handle: Handle, to point: CGPoint) -> CGRect {
        switch handle {
        case .top: return verticalEdge(original: original, anchorY: original.minY, to: point.y)
        case .bottom: return verticalEdge(original: original, anchorY: original.maxY, to: point.y)
        case .left: return horizontalEdge(original: original, anchorX: original.maxX, to: point.x)
        case .right: return horizontalEdge(original: original, anchorX: original.minX, to: point.x)
        default: return original // corners never reach here
        }
    }

    private static func verticalEdge(original: CGRect, anchorY: CGFloat, to y: CGFloat) -> CGRect {
        CGRect(x: original.minX, y: min(anchorY, y), width: original.width, height: abs(y - anchorY))
    }

    private static func horizontalEdge(original: CGRect, anchorX: CGFloat, to x: CGFloat) -> CGRect {
        CGRect(x: min(anchorX, x), y: original.minY, width: abs(x - anchorX), height: original.height)
    }

    private static func clamp(_ rect: CGRect, minSize: CGSize, within pageBounds: CGRect) -> CGRect {
        let sized = CGRect(x: rect.minX, y: rect.minY, width: max(rect.width, minSize.width), height: max(rect.height, minSize.height))
        let clamped = sized.intersection(pageBounds)
        return clamped.isNull ? sized : clamped
    }
}
