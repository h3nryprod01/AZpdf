#!/usr/bin/env swift
// B3.5.4 tool — OCR each page of the scanned corpus and emit per-line signal:
//   <file>\t<label>\t<line>\t<letterRatio>\t<confidence>\t<text>
// label = "formula" for scanned-08, "prose" otherwise. letterRatio = letters /
// non-whitespace chars (letters = Unicode general category L*; Vietnamese
// precomposed diacritics count as letters). Manual tool, not wired to CI.
import Foundation
import AppKit
import PDFKit
import Vision

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else {
    FileHandle.standardError.write("usage: ocr_lines.swift <pdf...>\n".data(using: .utf8)!)
    exit(2)
}

func isLetter(_ s: Unicode.Scalar) -> Bool {
    switch s.properties.generalCategory {
    case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: return true
    default: return false
    }
}

func letterRatio(_ s: String) -> Double {
    var letters = 0, nonws = 0
    for c in s {
        if c.isWhitespace { continue }
        nonws += 1
        if let sc = c.unicodeScalars.first, isLetter(sc) { letters += 1 }
    }
    return nonws == 0 ? 0.0 : Double(letters) / Double(nonws)
}

func render(_ page: PDFPage, scale: CGFloat) -> CGImage {
    let b = page.bounds(for: .cropBox)
    let img = NSImage(size: NSSize(width: b.width * scale, height: b.height * scale))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .cropBox, to: ctx)
    img.unlockFocus()
    return img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

func ocr(_ image: CGImage) -> [(text: String, conf: Float)] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["vi-VN", "en-US"]
    req.automaticallyDetectsLanguage = true
    req.usesLanguageCorrection = true
    try? VNImageRequestHandler(cgImage: image).perform([req])
    return (req.results ?? []).compactMap { ob in
        ob.topCandidates(1).first.map { ($0.string, $0.confidence) }
    }
}

for path in args {
    let url = URL(fileURLWithPath: path)
    guard let doc = PDFDocument(url: url) else {
        FileHandle.standardError.write("skip \(path)\n".data(using: .utf8)!); continue
    }
    let label = url.lastPathComponent.contains("08") ? "formula" : "prose"
    for pi in 0..<doc.pageCount {
        guard let page = doc.page(at: pi) else { continue }
        let lines = ocr(render(page, scale: 3.0))
        var confs: [Float] = []
        for (li, line) in lines.enumerated() {
            confs.append(line.conf)
            let ratio = String(format: "%.3f", letterRatio(line.text))
            let conf = String(format: "%.2f", line.conf)
            print("\(url.lastPathComponent)\t\(label)\t\(li)\t\(ratio)\t\(conf)\t\(line.text)")
        }
        if !confs.isEmpty {
            let avg = confs.reduce(0, +) / Float(confs.count)
            let mn = confs.min() ?? 0
            FileHandle.standardError.write(
                "\(url.lastPathComponent) [\(label)]: \(lines.count) dòng, avgConf=\(String(format: "%.2f", avg)), minConf=\(String(format: "%.2f", mn))\n".data(using: .utf8)!)
        }
    }
}
