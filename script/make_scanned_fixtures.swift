#!/usr/bin/env swift
// B3.5.2 — Sinh corpus "scan mô phỏng" 8 trang, mỗi trang là PDF chỉ-ảnh (không text layer
// ⇒ buộc đi đường OCR chứ không phải text layer). 0 dependency mới: chỉ Foundation +
// AppKit + PDFKit (framework hệ thống).
//
// Nguồn: README-VI.md, CONTRIBUTING-VI.md, SECURITY-VI.md (tiếng Việt thật, có dấu + ALL-CAPS,
// dự án tự sở hữu) cắt thành 7 trang văn xuôi; trang 8 là trang công thức từ
// Tests/Fixtures/source/formula-born-digital.pdf.
//
// Mỗi trang: render 200 DPI → xoay 0,4° → JPEG q70 (roundtrip để artefact thật sự bám pixel)
// → bọc lại thành PDF chỉ-ảnh qua PDFPage(image:). Ba bước làm bẩn là cố ý: raster sạch tinh
// sẽ làm Vision trông tốt hơn thực tế và kéo lệch ngưỡng ở B3.5.4. Dùng đúng MỘT mức cố định.
//
// Ground truth = chính chuỗi nguồn, ghi .txt cạnh mỗi .pdf.
// Chạy:  swift script/make_scanned_fixtures.swift    (từ gốc repo)

import Foundation
import AppKit
import PDFKit

let root = FileManager.default.currentDirectoryPath
let outDir = "\(root)/Tests/Fixtures/scanned"
let formulaPDF = "\(root)/Tests/Fixtures/source/formula-born-digital.pdf"
let dpi = 200
let pageW = Int(8.5 * Double(dpi))   // 1700
let pageH = Int(11.0 * Double(dpi))  // 2200
let rotateDeg = 0.4
let jpegQuality: CGFloat = 0.70
let pageCount = 8
let prosePageCount = 7

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("make_scanned_fixtures: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

// MARK: đọc nguồn tiếng Việt

var prose = ""
for f in ["README-VI.md", "CONTRIBUTING-VI.md", "SECURITY-VI.md"] {
    let p = "\(root)/\(f)"
    guard let s = try? String(contentsOfFile: p, encoding: .utf8), !s.isEmpty else { fail("thiếu nguồn prose: \(p)")
    }
    prose += s + "\n\n"
}
let chars = Array(prose)
let n = chars.count
guard n >= prosePageCount else { fail("không đủ text để cắt \(prosePageCount) trang") }

// chia 7 đoạn theo chỉ số ký tự, snap tiến tới xuống dòng tiếp theo để không cắt giữa từ
var proseChunks: [String] = []
var prev = 0
for i in 1...prosePageCount {
    let target = (i == prosePageCount) ? n : (n * i / prosePageCount)
    var end = target
    while end < n, chars[end] != "\n" { end += 1 }
    if end < n { end += 1 } // bao gồm ký tự xuống dòng
    proseChunks.append(String(chars[prev..<end]))
    prev = end
}
proseChunks = proseChunks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
if proseChunks.count != prosePageCount {
    fail("chia được \(proseChunks.count) đoạn prose, cần đúng \(prosePageCount)")
}

// MARK: render

func newCanvas() -> (NSImage, NSGraphicsContext) {
    let img = NSImage(size: NSSize(width: pageW, height: pageH))
    img.lockFocus()
    NSColor.white.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: pageW, height: pageH)).fill()
    guard let nsCtx = NSGraphicsContext.current else { fail("không có graphics context") }
    // xoay 0,4° quanh tâm — skew nhẹ kiểu scan
    let ctx = nsCtx.cgContext
    ctx.translateBy(x: CGFloat(pageW) / 2, y: CGFloat(pageH) / 2)
    ctx.rotate(by: CGFloat(rotateDeg * .pi / 180))
    ctx.translateBy(x: -CGFloat(pageW) / 2, y: -CGFloat(pageH) / 2)
    return (img, nsCtx)
}

func renderProse(_ text: String) -> CGImage {
    let (img, _) = newCanvas()
    let margin: CGFloat = 130
    let attr = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: 26, weight: .regular),
        .foregroundColor: NSColor.black,
    ])
    attr.draw(in: NSRect(x: margin, y: margin,
                         width: CGFloat(pageW) - 2 * margin,
                         height: CGFloat(pageH) - 2 * margin))
    img.unlockFocus()
    guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fail("render prose") }
    return cg
}

func renderFormulaPage() -> CGImage {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: formulaPDF)),
          let page = doc.page(at: 0) else { fail("mở \(formulaPDF)") }
    let (img, _) = newCanvas()
    guard let ctx = NSGraphicsContext.current?.cgContext else { fail("no ctx") }
    let bounds = page.bounds(for: .mediaBox)
    let margin: CGFloat = 160
    let availW = CGFloat(pageW) - 2 * margin
    let availH = CGFloat(pageH) - 2 * margin
    let scale = min(availW / bounds.width, availH / bounds.height)
    let drawW = bounds.width * scale
    let drawH = bounds.height * scale
    let dx = (CGFloat(pageW) - drawW) / 2 - bounds.origin.x * scale
    let dy = (CGFloat(pageH) - drawH) / 2 - bounds.origin.y * scale
    ctx.translateBy(x: dx, y: dy)
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx)
    img.unlockFocus()
    guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fail("render formula") }
    return cg
}

// MARK: JPEG q70 roundtrip (bám artefact thật) → bọc PDF chỉ-ảnh

func jpegRoundtrip(_ cg: CGImage) -> NSImage {
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else { fail("encode jpeg") }
    guard let decoded = NSImage(data: data) else { fail("decode jpeg") }
    return decoded
}

func writeImageOnlyPDF(_ image: NSImage, name: String) {
    guard let page = PDFPage(image: image) else { fail("PDFPage(image:) cho \(name)") }
    let doc = PDFDocument()
    doc.insert(page, at: 0)
    let url = URL(fileURLWithPath: "\(outDir)/\(name).pdf")
    if !doc.write(to: url) { fail("ghi \(url.path)") }
}

// MARK: main

try? FileManager.default.removeItem(atPath: outDir)
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for (i, chunk) in proseChunks.enumerated() {
    let name = String(format: "scanned-%02d", i + 1)
    let cg = renderProse(chunk)
    writeImageOnlyPDF(jpegRoundtrip(cg), name: name)
    try? chunk.write(toFile: "\(outDir)/\(name).txt", atomically: true, encoding: .utf8)
}

// trang 8: công thức
let formulaGroundTruth = """
Trang công thức (ground truth F1–F6):
F1 x = (-b ± √(b² - 4ac)) / 2a
F2 e^(iπ) + 1 = 0
F3 a² + b² = c²
F4 ∫₀^∞ e^(-x²) dx = √π / 2
F5 Σ(n=1..∞) 1/n² = π²/6
F6 E = mc²
"""
let fcg = renderFormulaPage()
writeImageOnlyPDF(jpegRoundtrip(fcg), name: "scanned-08")
try? formulaGroundTruth.write(toFile: "\(outDir)/scanned-08.txt", atomically: true, encoding: .utf8)

// báo cáo
let pdfs = (try? FileManager.default.contentsOfDirectory(atPath: outDir))?.filter { $0.hasSuffix(".pdf") } ?? []
let txts = (try? FileManager.default.contentsOfDirectory(atPath: outDir))?.filter { $0.hasSuffix(".txt") } ?? []
print("đã sinh \(pdfs.count) pdf, \(txts.count) txt vào \(outDir)")
if pdfs.count != pageCount || txts.count != pageCount { fail("mong \(pageCount) pdf + \(pageCount) txt") }
