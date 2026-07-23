import mupdf from "mupdf"

function rectToPortable(page, rect) {
    var value = mupdf.Rect.transform(rect, page.getTransform())
    return {
        origin: { x: value[0], y: value[1] },
        size: { width: value[2] - value[0], height: value[3] - value[1] }
    }
}

function rectFromPortable(page, bounds) {
    var value = [
        bounds.origin.x,
        bounds.origin.y,
        bounds.origin.x + bounds.size.width,
        bounds.origin.y + bounds.size.height
    ]
    return mupdf.Rect.transform(value, mupdf.Matrix.invert(page.getTransform()))
}

function colorToPortable(color) {
    if (!color || color.length === 0) return null
    if (color.length === 1) return { red: color[0], green: color[0], blue: color[0], alpha: 1 }
    if (color.length === 3) return { red: color[0], green: color[1], blue: color[2], alpha: 1 }
    var c = color[0], m = color[1], y = color[2], k = color[3]
    return {
        red: 1 - Math.min(1, c + k),
        green: 1 - Math.min(1, m + k),
        blue: 1 - Math.min(1, y + k),
        alpha: 1
    }
}

function colorFromPortable(color) {
    if (!color) return [0, 0, 0]
    return [color.red, color.green, color.blue]
}

function boolFromObject(object, key) {
    var value = object.get(key)
    return value && value.isBoolean() ? value.asBoolean() : false
}

function alignmentName(value) {
    if (value === 1) return "center"
    if (value === 2) return "right"
    return "left"
}

function alignmentValue(value) {
    if (value === "center") return 1
    if (value === "right") return 2
    return 0
}

function kindForAnnotation(annotation) {
    var type = annotation.getType()
    if (type === "Text") return "note"
    if (type === "FreeText") return "freeText"
    if (type === "Stamp") {
        var object = annotation.getObject()
        if (annotation.getIntent() === "StampImage" || boolFromObject(object, "AZpdfImage")) return "image"
    }
    // Without these, every highlight and every hand-drawn signature came back
    // as "unknown" even though PDFAnnotationKind already declares them. The
    // Linux shell reads documents through this engine, so a file annotated on
    // macOS was being misclassified there.
    if (type === "Highlight") return "highlight"
    if (type === "Ink") return "ink"
    if (type === "Link") return "link"
    if (type === "Widget") return "widget"
    if (type === "Redact") return "redaction"
    if (type === "Square" || type === "Circle" || type === "Line") return "shape"
    return "unknown"
}

function typeForKind(kind) {
    if (kind === "note") return "Text"
    if (kind === "freeText") return "FreeText"
    if (kind === "image") return "Stamp"
    throw new Error("Unsupported annotation kind: " + kind)
}

function listAnnotations(document, pageIndex) {
    var page = document.loadPage(pageIndex)
    return page.getAnnotations().map(function (annotation) {
        var object = annotation.getObject()
        var appearance = annotation.hasDefaultAppearance() ? annotation.getDefaultAppearance() : null
        var style = appearance ? {
            fontName: appearance.font || "Helv",
            fontSize: appearance.size || 14,
            color: colorToPortable(appearance.color) || { red: 0, green: 0, blue: 0, alpha: 1 },
            alignment: annotation.hasQuadding() ? alignmentName(annotation.getQuadding()) : "left",
            isBold: boolFromObject(object, "AZpdfBold"),
            isItalic: boolFromObject(object, "AZpdfItalic"),
            isUnderline: boolFromObject(object, "AZpdfUnderline")
        } : null
        var name = annotation.getName()
        if (!name) name = object.isIndirect() ? "object-" + object.asIndirect() : "page-" + pageIndex + "-annotation"
        return {
            id: name,
            kind: kindForAnnotation(annotation),
            pageIndex: pageIndex,
            bounds: rectToPortable(
                page,
                annotation.hasRect() ? annotation.getRect() : annotation.getBounds()
            ),
            contents: annotation.getContents() || null,
            color: colorToPortable(annotation.getColor()),
            opacity: annotation.getOpacity(),
            coordinateSpace: "pdfBottomLeft",
            textStyle: style
        }
    })
}

function htmlEscape(value) {
    return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function cssColor(color) {
    var value = color || { red: 0, green: 0, blue: 0 }
    return "rgb(" +
        Math.round(value.red * 255) + "," +
        Math.round(value.green * 255) + "," +
        Math.round(value.blue * 255) + ")"
}

function richContents(text, style) {
    var value = htmlEscape(text).replace(/\n/g, "<br/>")
    if (style.isUnderline) value = "<u>" + value + "</u>"
    if (style.isItalic) value = "<i>" + value + "</i>"
    if (style.isBold) value = "<b>" + value + "</b>"
    return "<body><p style=\"color:" + cssColor(style.color) +
        ";text-align:" + style.alignment + ";\">" + value + "</p></body>"
}

function upsertAnnotation(document, payload, imagePath) {
    var page = document.loadPage(payload.pageIndex)
    var expectedType = typeForKind(payload.kind)
    var annotation = null
    page.getAnnotations().forEach(function (candidate) {
        if (candidate.getName() === payload.id) annotation = candidate
    })
    if (annotation && annotation.getType() !== expectedType) {
        page.deleteAnnotation(annotation)
        annotation = null
    }
    var created = false
    if (!annotation) {
        annotation = page.createAnnotation(expectedType)
        created = true
    }

    annotation.setName(payload.id)
    annotation.setRect(rectFromPortable(page, payload.bounds))
    annotation.setOpacity(payload.opacity == null ? 1 : payload.opacity)

    if (payload.kind === "freeText") {
        var style = payload.textStyle || {
            fontName: "Helv", fontSize: 14,
            color: { red: 0, green: 0, blue: 0, alpha: 1 },
            alignment: "left", isBold: false, isItalic: false, isUnderline: false
        }
        var contents = payload.contents || ""
        annotation.setContents(contents)
        annotation.setDefaultAppearance(style.fontName || "Helv", style.fontSize || 14, colorFromPortable(style.color))
        annotation.setQuadding(alignmentValue(style.alignment))
        var object = annotation.getObject()
        object.put("AZpdfBold", !!style.isBold)
        object.put("AZpdfItalic", !!style.isItalic)
        object.put("AZpdfUnderline", !!style.isUnderline)
        if ((style.isBold || style.isItalic || style.isUnderline) && annotation.hasRichContents()) {
            try {
                annotation.setRichDefaults(
                    "font-size:" + style.fontSize + "pt;color:" + cssColor(style.color)
                )
                annotation.setRichContents(contents, richContents(contents, style))
            } catch (_) {
                annotation.setContents(contents)
            }
        }
    } else if (payload.kind === "note") {
        annotation.setContents(payload.contents || "")
        annotation.setIcon("Note")
        annotation.setColor(colorFromPortable(payload.color || { red: 1, green: 0.82, blue: 0, alpha: 1 }))
    } else if (payload.kind === "image") {
        if (created && !imagePath) throw new Error("Missing image path for new image annotation")
        annotation.setIntent("StampImage")
        if (imagePath) annotation.setStampImage(new mupdf.Image(imagePath))
        annotation.getObject().put("AZpdfImage", true)
    }
    annotation.update()
    page.update()
}

function removeAnnotation(document, pageIndex, id) {
    var page = document.loadPage(pageIndex)
    var removed = false
    page.getAnnotations().forEach(function (annotation) {
        if (annotation.getName() === id) {
            page.deleteAnnotation(annotation)
            removed = true
        }
    })
    if (!removed) throw new Error("Annotation not found: " + id)
    page.update()
}

var mode = scriptArgs[0]
var input = scriptArgs[1]
var document = mupdf.Document.openDocument(input)

if (mode === "list") {
    print(JSON.stringify(listAnnotations(document, Number(scriptArgs[2]))))
} else if (mode === "upsert") {
    var output = scriptArgs[2]
    var payload = JSON.parse(scriptArgs[3])
    upsertAnnotation(document, payload, scriptArgs[4] || null)
    document.save(output, "compress,garbage=3,appearance=yes")
} else if (mode === "remove") {
    var removeOutput = scriptArgs[2]
    removeAnnotation(document, Number(scriptArgs[3]), scriptArgs[4])
    document.save(removeOutput, "compress,garbage=3,appearance=yes")
} else {
    throw new Error("Unknown mode: " + mode)
}
