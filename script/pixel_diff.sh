#!/usr/bin/env bash
# B6.2 — Pixel-diff rendered PNGs against the committed baseline. 0 new dependency: the
# comparison runs through CoreGraphics/ImageIO in an embedded Swift program.
#
# Metric — và một ngưỡng đã bị ĐO LÀ SAI rồi gỡ bỏ, ghi lại để không ai đặt nó lại:
#
#   Bản đầu FAIL khi >0,1% pixel lệch. Đo 2026-08-08, hỏng theo hai cách độc lập:
#     · self-test bên dưới: dịch ảnh 2 px → 204/1.938.816 px (0,011%) → gate vẫn XANH.
#     · so trang 1 với trang 2 của cùng tài liệu (nội dung khác hẳn, cùng kích thước)
#       → 673/2.003.960 px (0,034%) → gate vẫn XANH. Gate bảo hai trang khác nhau là giống nhau.
#
#   Nguyên nhân gốc: phần trăm trên TỔNG số pixel là thước đo vô nghĩa với tài liệu thưa. Trang
#   A4 chữ đen nền trắng có ~99,97% pixel trắng, nên dù chữ sai hoàn toàn, tỉ lệ vẫn không chạm
#   0,1%. Mọi ngưỡng tỉ lệ đều mắc bệnh này; vặn nhỏ con số chỉ dời chỗ hỏng chứ không chữa.
#
# Nên gate hiện tại KHÔNG có ngưỡng tỉ lệ:
#   · một pixel "lệch" nếu MỘT kênh nào đó lệch quá 8/255 — dung sai này là nhiễu làm tròn thật
#     của rasterizer, và nó theo TỪNG PIXEL, không phải theo số lượng.
#   · FAIL nếu có BẤT KỲ pixel nào lệch. Không con số nào để vặn cho xanh.
#
# Làm được vì render đã chứng minh là tất định byte-for-byte (B6.1, đo lại độc lập 6/6 file).
# Khi runner macOS đổi phiên bản thì gate SẼ đỏ — đó là đúng, render đã đổi thật và cần người
# nhìn. Quy trình cập nhật baseline nằm ở qa-report/pixel-diff-baseline-policy.md, chứ không
# nằm ở một con số đoán trong file này.
#
# Phần trăm vẫn được in ra làm CHẨN ĐOÁN: đỏ với 40 px là nhiễu hệ điều hành, đỏ với 600 px là
# thay đổi render thật. Hai loại đỏ đó cần xử khác nhau.
#
# Usage:
#   ./script/pixel_diff.sh <baselineDir> <renderedDir>     # compare every matching PNG
#   ./script/pixel_diff.sh <a.png> <b.png>                 # compare one pair
#   ./script/pixel_diff.sh --self-test                     # plant a 2px shift, assert the
#                                                          # gate catches it (fail-open check)
#
# Exit: 0 if every pair is within tolerance; 1 if any pair exceeds it (or differs in size); 2
# on misuse.
set -euo pipefail

if [ "$#" -eq 1 ] && [ "$1" = "--self-test" ]; then
    swift - "$@" <<'SWIFT'
import Foundation
import CoreGraphics
import ImageIO

// --self-test: take the first baseline PNG, shift its content 2px right, and confirm the gate
// flags it. A gate that stays green on a real change is worse than no gate (it looks like it is
// guarding). Mirrors the planted-probe pattern the other audit_* gates already use.
let CHANNEL_TOLERANCE = 8
// Không có ngưỡng tỉ lệ. Xem khối chú thích đầu file — đo được là 0.1% để lọt cả 2px shift
// lẫn hai trang khác hẳn nhau. Gate là: KHÔNG pixel nào được lệch quá CHANNEL_TOLERANCE.
let baselineDir = "Tests/Fixtures/render/baseline"

func fail(_ m: String) -> Never { FileHandle.standardError.write("pixel_diff: \(m)\n".data(using:.utf8)!); exit(1) }
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue

func loadPNG(_ path: String) -> CGImage {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else { fail("cannot read \(path)") }
    return i
}
func mkctx(_ w: Int, _ h: Int) -> CGContext {
    guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w*4, space: cs, bitmapInfo: info) else { fail("ctx") }
    return c
}
func rawBytes(_ img: CGImage) -> [UInt8] {
    let c = mkctx(img.width, img.height)
    c.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    let p = c.data!.assumingMemoryBound(to: UInt8.self)
    return Array(UnsafeBufferPointer(start: p, count: img.width * img.height * 4))
}
func diffCount(_ a: CGImage, _ b: CGImage) -> (Int, Int)? {
    guard a.width == b.width, a.height == b.height else { return nil }
    let pa = rawBytes(a), pb = rawBytes(b), n = a.width * a.height
    var d = 0
    for i in 0..<n {
        let o = i * 4
        if abs(Int(pa[o]) - Int(pb[o])) > CHANNEL_TOLERANCE ||
           abs(Int(pa[o+1]) - Int(pb[o+1])) > CHANNEL_TOLERANCE ||
           abs(Int(pa[o+2]) - Int(pb[o+2])) > CHANNEL_TOLERANCE { d += 1 }
    }
    return (d, n)
}

let names = ((try? FileManager.default.contentsOfDirectory(atPath: baselineDir)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
guard let first = names.first else { fail("no baseline PNGs in \(baselineDir) — run render_baselines first") }
let img = loadPNG("\(baselineDir)/\(first)")

// shift content 2px right: left 2 columns become the white ground, right 2 columns clip.
let shifted = mkctx(img.width, img.height)
shifted.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
shifted.fill(CGRect(x: 0, y: 0, width: img.width, height: img.height))
shifted.draw(img, in: CGRect(x: 2, y: 0, width: img.width, height: img.height))
guard let shiftedImg = shifted.makeImage() else { fail("makeImage shifted") }

guard let (d, n) = diffCount(img, shiftedImg) else { fail("self-test: dims mismatch (unexpected)") }
let pct = Double(d) / Double(n)
if d == 0 {
    fail("self-test FAILED: a 2px shift moved \(d)/\(n) px (\(String(format: "%.3f%%", pct*100))) but the gate stayed GREEN — it cannot detect a real change. Comparator broken.")
}
print("self-test OK: 2px shift on \(first) detected — \(d)/\(n) px (\(String(format: "%.2f%%", pct*100))) differ, cho phép 0")
exit(0)
SWIFT
    exit $?
fi

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <baselineDir-or-png> <renderedDir-or-png>" >&2
    echo "       $0 --self-test" >&2
    exit 2
fi

swift - "$@" <<'SWIFT'
import Foundation
import CoreGraphics
import ImageIO

let CHANNEL_TOLERANCE = 8      // >8/255 on any channel = real diff (rasterizer rounding otherwise)
// KHÔNG có ngưỡng tỉ lệ — xem chú thích đầu file. Gate: 0 pixel được phép lệch.

func fail(_ m: String) -> Never { FileHandle.standardError.write("pixel_diff: \(m)\n".data(using:.utf8)!); exit(1) }
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue

func loadPNG(_ path: String) -> CGImage {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else { fail("cannot read PNG: \(path)") }
    return i
}
func rawBytes(_ img: CGImage) -> [UInt8] {
    guard let c = CGContext(data: nil, width: img.width, height: img.height, bitsPerComponent: 8,
                            bytesPerRow: img.width*4, space: cs, bitmapInfo: info) else { fail("ctx") }
    c.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    let p = c.data!.assumingMemoryBound(to: UInt8.self)
    return Array(UnsafeBufferPointer(start: p, count: img.width * img.height * 4))
}
// (diffPixels, totalPixels); nil when dimensions differ (a real render change in size).
func diffCount(_ a: CGImage, _ b: CGImage) -> (Int, Int)? {
    guard a.width == b.width, a.height == b.height else { return nil }
    let pa = rawBytes(a), pb = rawBytes(b), n = a.width * a.height
    var d = 0
    for i in 0..<n {
        let o = i * 4
        // noneSkipLast: 3 component bytes + 1 skipped. Both images share this layout, so the
        // channel identity (R vs B) is irrelevant — we flag any position that moved.
        if abs(Int(pa[o]) - Int(pb[o])) > CHANNEL_TOLERANCE ||
           abs(Int(pa[o+1]) - Int(pb[o+1])) > CHANNEL_TOLERANCE ||
           abs(Int(pa[o+2]) - Int(pb[o+2])) > CHANNEL_TOLERANCE { d += 1 }
    }
    return (d, n)
}

let args = Array(CommandLine.arguments.dropFirst())   // drop the "-" placeholder
guard args.count == 2 else { fail("need exactly two paths") }
let (pA, pB) = (args[0], args[1])

func isDir(_ p: String) -> Bool {
    var d: ObjCBool = false
    return FileManager.default.fileExists(atPath: p, isDirectory: &d) && d.boolValue
}
func pngs(_ dir: String) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
}

var pairs: [(String, String)] = []
var mismatch = 0
if isDir(pA) && isDir(pB) {
    for name in pngs(pA) {
        let b = "\(pB)/\(name)"
        if FileManager.default.fileExists(atPath: b) { pairs.append(("\(pA)/\(name)", b)) }
        else { print("MISSING in rendered: \(name)"); mismatch += 1 }
    }
    for name in pngs(pB) where !FileManager.default.fileExists(atPath: "\(pA)/\(name)") {
        print("EXTRA in rendered (no baseline): \(name)"); mismatch += 1
    }
} else {
    pairs.append((pA, pB))
}
if mismatch > 0 { fail("\(mismatch) image(s) unpaired — baseline and rendered sets do not match") }

var totalDiff = 0, totalPx = 0, failures = 0
for (a, b) in pairs {
    let name = (a as NSString).lastPathComponent
    switch diffCount(loadPNG(a), loadPNG(b)) {
    case nil:
        print("FAIL  \(name)  dimensions differ"); failures += 1
    case let (d, n)?:
        let pct = n > 0 ? Double(d) / Double(n) : 0
        let ok = d == 0
        print("\(ok ? "ok" : "FAIL")  \(name)  \(d) / \(n) px (\(String(format: "%.4f%%", pct * 100)))")
        if !ok { failures += 1 }
        totalDiff += d; totalPx += n
    }
}
let overall = totalPx > 0 ? Double(totalDiff) / Double(totalPx) : 0
print("TOTAL  \(totalDiff) / \(totalPx) px differ (\(String(format: "%.4f%%", overall * 100)))  cho phép 0  => \(failures == 0 ? "PASS" : "FAIL")")
exit(failures > 0 ? 1 : 0)
SWIFT
