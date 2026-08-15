#!/usr/bin/env swift
// B6.1 — Render fixture PDF pages to PNG baselines at exactly 144 DPI for pixel-diff
// regression (Pha 6). 0 new dependency: Foundation + CoreGraphics + ImageIO + PDFKit
// (system frameworks only — see QUY TẮC in activeContext.md: no imaging library pulled in).
//
// Determinism is the whole point of B6.1: same input MUST give byte-identical output, or
// pixel-diff is meaningless. So the renderer writes straight to an sRGB bitmap context (no
// NSImage round-trip, which has its own rep heuristics) and the PNG via ImageIO with no
// properties (no timestamp, no profile metadata). Measured 2026-08-08: all six fixtures are
// byte-identical across two runs, including the image-only scanned pages.
//
// DPI is a FIXED CONSTANT, not a flag — baked into every filename (-144dpi) so it cannot drift
// silently. Change it and every baseline name changes; that is the point.
//
// Usage (from repo root):
//   swift script/render_baselines.swift                 # (re)generate baselines
//   swift script/render_baselines.swift --out <dir>     # generate into <dir> (CI fresh render)
//   swift script/render_baselines.swift --check         # re-render to temp, exit 1 if any PNG
//                                                       # differs byte-for-byte from the baseline

import Foundation
import CoreGraphics
import ImageIO
import PDFKit

let dpi = 144
let scale = Double(dpi) / 72.0   // PDF points are 1/72 inch
let root = FileManager.default.currentDirectoryPath
let baselineDir = "\(root)/Tests/Fixtures/render/baseline"

// Fixed manifest. Each entry is (fixture path, 0-indexed page). The output filename is
// 1-indexed. Adding a fixture here is the only way to extend coverage — pixel_diff walks the
// baseline dir by stem, so a new entry shows up automatically.
let manifest: [(String, Int)] = [
    ("Tests/Fixtures/source/two-page.pdf", 0),
    ("Tests/Fixtures/source/two-page.pdf", 1),
    ("Tests/Fixtures/source/annotated-highlight-ink.pdf", 0),
    ("Tests/Fixtures/source/formula-born-digital.pdf", 0),
    // Hai trang scan CỐ Ý không có trong danh sách. Đo 2026-08-08: chúng render ra
    // 3,9 MB + 4,0 MB, tức 7,9/8,0 MB của toàn bộ baseline, trong khi bốn fixture còn lại
    // cộng lại chỉ 208 KB. Đổi lại được gì: chúng là ảnh chụp, render chúng chỉ kiểm việc
    // blit ảnh — không kiểm bố cục chữ, không kiểm vẽ chú thích, tức không kiểm đúng thứ
    // pixel-diff sinh ra để canh. Nhánh scan đã có ScannedFixtureTests và cờ OCR của Pha 3.5.
    // 38× dung lượng cho gần như không tín hiệu ⇒ bỏ.
]

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("render_baselines: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue

func renderPage(_ path: String, _ idx: Int) -> CGImage {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { fail("open \(path)") }
    guard let page = doc.page(at: idx) else { fail("page \(idx) of \(path)") }
    let b = page.bounds(for: .mediaBox)
    let pw = Int(b.width * scale), ph = Int(b.height * scale)
    guard pw > 0, ph > 0 else { fail("zero-size page \(path) p\(idx)") }
    guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8,
                              bytesPerRow: 0, space: cs, bitmapInfo: bitmapInfo) else {
        fail("context for \(path) p\(idx)")
    }
    // White ground: PDFs need not paint a background, and a transparent page would make
    // anti-aliasing edges count as spurious diffs.
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx)
    guard let img = ctx.makeImage() else { fail("makeImage \(path) p\(idx)") }
    return img
}

func writePNG(_ img: CGImage, to path: String) {
    guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                     "public.png" as CFString, 1, nil) else {
        fail("create destination \(path)")
    }
    // nil properties: no timestamp/profile metadata — keeps bytes stable across runs.
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { fail("finalize \(path)") }
}

func stem(_ path: String) -> String {
    (path as NSString).lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
}

func pngName(_ path: String, _ idx: Int) -> String {
    "\(stem(path))-p\(idx + 1)-\(dpi)dpi.png"
}

func generate(into dir: String) {
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    for (path, idx) in manifest {
        let out = "\(dir)/\(pngName(path, idx))"
        writePNG(renderPage(path, idx), to: out)
        let bytes = (try? FileManager.default.attributesOfItem(atPath: out)[.size] as? Int) ?? 0
        print("wrote \(out)  (\(bytes) bytes)")
    }
    print("generated \(manifest.count) baseline PNG(s) at \(dpi) DPI into \(dir)")
}

// MARK: --check: re-render every fixture to a temp dir and byte-compare against the committed
// baseline. Any difference means the renderer is not reproducible, in which case pixel-diff is
// meaningless and the whole phase is blocked (see B6.1).
func runCheck() -> Never {
    let tmp = NSTemporaryDirectory() + "azpdf_render_check"
    try? FileManager.default.removeItem(atPath: tmp)
    try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    var diffs = 0
    for (path, idx) in manifest {
        let name = pngName(path, idx)
        let base = "\(baselineDir)/\(name)"
        guard FileManager.default.fileExists(atPath: base) else {
            fail("missing baseline \(name) — generate first (drop --check)")
        }
        let tmpPath = "\(tmp)/\(name)"
        writePNG(renderPage(path, idx), to: tmpPath)
        let a = FileManager.default.contents(atPath: base)!
        let b = FileManager.default.contents(atPath: tmpPath)!
        if a != b {
            diffs += 1
            FileHandle.standardError.write(
                "render_baselines: \(name) differs from baseline — NOT byte-reproducible\n"
                    .data(using: .utf8)!)
        }
    }
    if diffs > 0 {
        fail("\(diffs) baseline(s) not byte-reproducible at \(dpi) DPI — pixel-diff is meaningless; see B6.1")
    }
    print("check OK: all \(manifest.count) baselines byte-reproducible at \(dpi) DPI")
    exit(0)
}

// MARK: arg parsing

let args = Array(CommandLine.arguments.dropFirst())
if args.contains("--check") { runCheck() }
var outDir = baselineDir
if let i = args.firstIndex(of: "--out"), i + 1 < args.count { outDir = args[i + 1] }
generate(into: outDir)
