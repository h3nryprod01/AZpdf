import AppKit
import PDFKit
import AZpdfCore

/// macOS adapter. A Windows/Linux engine must conform to the same core contract.
struct PDFKitDocumentEngine: PDFDocumentReadingEngine,
    PDFDocumentOutlineEngine,
    PDFDocumentFormEngine,
    PDFDocumentSecurityEngine
{
    let capabilities: PDFEngineCapabilities = [
        .open,
        .save,
        .render,
        .extractText,
        .search,
        .metadata,
        .annotations,
        .forms,
        .pageEditing,
        .encryption,
        .outline
    ]

    func load(data: Data) throws -> PDFDocument {
        guard let document = PDFDocument(data: data) else { throw PDFEngineError.invalidDocument }
        return document
    }

    func dataRepresentation(of document: PDFDocument) throws -> Data {
        guard let data = document.dataRepresentation() else { throw PDFEngineError.invalidDocument }
        return data
    }

    func pageCount(of document: PDFDocument) -> Int { document.pageCount }

    func apply(_ operation: DocumentOperation, to document: PDFDocument) throws {
        switch operation {
        case let .rotate(page):
            guard let pdfPage = document.page(at: page) else { throw PDFEngineError.invalidPageIndex }
            pdfPage.rotation = (pdfPage.rotation + 90) % 360
        case let .duplicate(page):
            guard let pdfPage = document.page(at: page), let copy = pdfPage.copy() as? PDFPage else {
                throw PDFEngineError.invalidPageIndex
            }
            document.insert(copy, at: page + 1)
        case let .delete(page):
            guard document.pageCount > 1, document.page(at: page) != nil else {
                throw PDFEngineError.invalidPageIndex
            }
            document.removePage(at: page)
        case let .movePages(from, destination):
            guard !from.isEmpty, from.allSatisfy({ document.page(at: $0) != nil }) else {
                throw PDFEngineError.invalidPageIndex
            }
            let pages = from.compactMap { document.page(at: $0) }
            for index in from.sorted(by: >) { document.removePage(at: index) }
            let adjustedDestination = max(0, min(destination, document.pageCount))
            for (offset, page) in pages.enumerated() { document.insert(page, at: adjustedDestination + offset) }
        case let .insertDocument(data, pageIndexes, destination):
            guard let source = PDFDocument(data: data) else { throw PDFEngineError.invalidDocument }
            let indexes = pageIndexes ?? Array(0..<source.pageCount)
            guard indexes.allSatisfy({ source.page(at: $0) != nil }) else {
                throw PDFEngineError.invalidPageIndex
            }
            let insertAt = max(0, min(destination, document.pageCount))
            for (offset, sourceIndex) in indexes.enumerated() {
                guard let page = source.page(at: sourceIndex)?.copy() as? PDFPage else {
                    throw PDFEngineError.invalidPageIndex
                }
                document.insert(page, at: insertAt + offset)
            }
        case let .setMetadata(metadata):
            var attributes = document.documentAttributes ?? [:]
            attributes[PDFDocumentAttribute.titleAttribute] = metadata.title
            attributes[PDFDocumentAttribute.authorAttribute] = metadata.author
            attributes[PDFDocumentAttribute.subjectAttribute] = metadata.subject
            attributes[PDFDocumentAttribute.keywordsAttribute] = metadata.keywords.isEmpty
                ? nil
                : metadata.keywords.joined(separator: ", ")
            attributes[PDFDocumentAttribute.creatorAttribute] = metadata.creator
            attributes[PDFDocumentAttribute.producerAttribute] = metadata.producer
            document.documentAttributes = attributes
        case let .setFormValue(fieldID, value):
            var matched = false
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                for (offset, annotation) in page.annotations.enumerated() where isWidget(annotation) {
                    let id = annotation.fieldName ?? "\(pageIndex):\(offset)"
                    guard id == fieldID else { continue }
                    guard !annotation.isReadOnly else { throw PDFEngineError.readOnlyDocument }
                    annotation.widgetStringValue = value
                    matched = true
                }
            }
            guard matched else { throw PDFEngineError.operationNotSupported }
        case .insertPages,
             .addAnnotation,
             .redact,
             .upsertAnnotation,
             .upsertImageAnnotation,
             .removeAnnotation,
             .flattenAnnotations,
             .setOutline,
             .upsertEmbeddedFile,
             .removeEmbeddedFile:
            throw PDFEngineError.operationNotSupported
        }
    }

    func metadata(of document: PDFDocument) throws -> PDFDocumentMetadata {
        let attributes = document.documentAttributes ?? [:]
        let keywords = (attributes[PDFDocumentAttribute.keywordsAttribute] as? String)?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        return PDFDocumentMetadata(
            title: attributes[PDFDocumentAttribute.titleAttribute] as? String,
            author: attributes[PDFDocumentAttribute.authorAttribute] as? String,
            subject: attributes[PDFDocumentAttribute.subjectAttribute] as? String,
            keywords: keywords,
            creator: attributes[PDFDocumentAttribute.creatorAttribute] as? String,
            producer: attributes[PDFDocumentAttribute.producerAttribute] as? String
        )
    }

    func pageDescriptor(at index: Int, in document: PDFDocument) throws -> PDFPageDescriptor {
        guard let page = document.page(at: index) else { throw PDFEngineError.invalidPageIndex }
        return PDFPageDescriptor(
            index: index,
            label: page.label,
            mediaBox: portableRect(page.bounds(for: .mediaBox)),
            cropBox: portableRect(page.bounds(for: .cropBox)),
            rotation: page.rotation
        )
    }

    func text(ofPage index: Int, in document: PDFDocument) throws -> String {
        guard let page = document.page(at: index) else { throw PDFEngineError.invalidPageIndex }
        return page.string ?? ""
    }

    func annotations(onPage index: Int, in document: PDFDocument) throws -> [PDFAnnotationDescriptor] {
        guard let page = document.page(at: index) else { throw PDFEngineError.invalidPageIndex }
        return page.annotations.enumerated().map { offset, annotation in
            PDFAnnotationDescriptor(
                id: "\(index):\(offset):\(annotation.type ?? "unknown")",
                kind: annotationKind(for: annotation.type),
                pageIndex: index,
                bounds: portableRect(annotation.bounds),
                contents: annotation.contents,
                color: portableColor(annotation.color),
                opacity: Double(annotation.color.alphaComponent)
            )
        }
    }

    func render(_ request: PDFRenderRequest, in document: PDFDocument) throws -> PDFRenderedPage {
        guard request.scale > 0, let page = document.page(at: request.pageIndex) else {
            throw PDFEngineError.invalidPageIndex
        }
        let pageBounds = page.bounds(for: .cropBox)
        let size = CGSize(
            width: max(1, pageBounds.width * request.scale),
            height: max(1, pageBounds.height * request.scale)
        )
        let image = page.thumbnail(of: size, for: .cropBox)
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw PDFEngineError.ioFailure("Không thể render trang PDF.")
        }
        return PDFRenderedPage(
            size: PDFSize(width: Double(size.width), height: Double(size.height)),
            format: .png,
            data: data,
            pageBox: portableRect(pageBounds),
            rotation: page.rotation
        )
    }

    func outline(of document: PDFDocument) throws -> [PDFOutlineItem] {
        guard let root = document.outlineRoot else { return [] }
        return (0..<root.numberOfChildren).compactMap { index in
            root.child(at: index).map { outlineItem($0, path: "\(index)", document: document) }
        }
    }

    func formFields(in document: PDFDocument) throws -> [PDFFormFieldDescriptor] {
        var fields: [PDFFormFieldDescriptor] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for (offset, annotation) in page.annotations.enumerated() where isWidget(annotation) {
                let maximumLength = annotation.maximumLength > 0 ? annotation.maximumLength : nil
                fields.append(PDFFormFieldDescriptor(
                    id: annotation.fieldName ?? "\(pageIndex):\(offset)",
                    name: annotation.fieldName,
                    kind: formFieldKind(annotation),
                    pageIndex: pageIndex,
                    bounds: portableRect(annotation.bounds),
                    value: annotation.widgetStringValue,
                    defaultValue: annotation.widgetDefaultStringValue,
                    choices: annotation.choices ?? [],
                    isReadOnly: annotation.isReadOnly,
                    isMultiline: annotation.isMultiline,
                    isPassword: annotation.isPasswordField,
                    maximumLength: maximumLength
                ))
            }
        }
        return fields
    }

    func security(of document: PDFDocument) -> PDFDocumentSecurity {
        PDFDocumentSecurity(
            isEncrypted: document.isEncrypted,
            isLocked: document.isLocked,
            allowsPrinting: document.allowsPrinting,
            allowsCopying: document.allowsCopying,
            allowsDocumentChanges: document.allowsDocumentChanges,
            allowsDocumentAssembly: document.allowsDocumentAssembly,
            allowsContentAccessibility: document.allowsContentAccessibility,
            allowsCommenting: document.allowsCommenting,
            allowsFormFieldEntry: document.allowsFormFieldEntry
        )
    }

    func unlock(_ document: PDFDocument, password: String) throws {
        guard document.isLocked else { return }
        guard document.unlock(withPassword: password) else { throw PDFEngineError.invalidPassword }
    }

    private func portableRect(_ rect: CGRect) -> PDFRect {
        PDFRect(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.size.width),
            height: Double(rect.size.height)
        )
    }

    private func portableColor(_ color: NSColor) -> PDFColor? {
        guard let converted = color.usingColorSpace(.sRGB) else { return nil }
        return PDFColor(
            red: Double(converted.redComponent),
            green: Double(converted.greenComponent),
            blue: Double(converted.blueComponent),
            alpha: Double(converted.alphaComponent)
        )
    }

    private func annotationKind(for type: String?) -> PDFAnnotationKind {
        switch type {
        case PDFAnnotationSubtype.text.rawValue: .note
        case PDFAnnotationSubtype.highlight.rawValue: .highlight
        case PDFAnnotationSubtype.freeText.rawValue: .freeText
        case PDFAnnotationSubtype.ink.rawValue: .ink
        case PDFAnnotationSubtype.link.rawValue: .link
        case PDFAnnotationSubtype.widget.rawValue: .widget
        case "Redact": .redaction
        case PDFAnnotationSubtype.stamp.rawValue: .image
        default: .unknown
        }
    }

    private func isWidget(_ annotation: PDFAnnotation) -> Bool {
        annotation.type?.caseInsensitiveCompare(PDFAnnotationSubtype.widget.rawValue) == .orderedSame
            || annotation.widgetFieldType == PDFAnnotationWidgetSubtype.text
            || annotation.widgetFieldType == PDFAnnotationWidgetSubtype.button
            || annotation.widgetFieldType == PDFAnnotationWidgetSubtype.choice
            || annotation.widgetFieldType == PDFAnnotationWidgetSubtype.signature
    }

    private func formFieldKind(_ annotation: PDFAnnotation) -> PDFFormFieldKind {
        switch annotation.widgetFieldType {
        case PDFAnnotationWidgetSubtype.text: .text
        case PDFAnnotationWidgetSubtype.choice: .choice
        case PDFAnnotationWidgetSubtype.signature: .signature
        case PDFAnnotationWidgetSubtype.button:
            switch annotation.widgetControlType.rawValue {
            case 0: .pushButton
            case 1: .radioButton
            case 2: .checkBox
            default: .unknown
            }
        default: .unknown
        }
    }

    private func outlineItem(_ outline: PDFOutline, path: String, document: PDFDocument) -> PDFOutlineItem {
        let destination = outline.destination
        let pageIndex = destination?.page.map { document.index(for: $0) }
        let children = (0..<outline.numberOfChildren).compactMap { index in
            outline.child(at: index).map {
                outlineItem($0, path: "\(path).\(index)", document: document)
            }
        }
        return PDFOutlineItem(
            id: path,
            title: outline.label ?? "",
            pageIndex: pageIndex,
            destination: destination.map {
                PDFPoint(x: Double($0.point.x), y: Double($0.point.y))
            },
            isOpen: outline.isOpen,
            children: children
        )
    }
}
