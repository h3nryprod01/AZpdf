import SwiftUI
import AppKit

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L("AZpdf Help")).font(.title.weight(.bold))
                GroupBox(L("Getting Started")) {
                    Text(L("Use ⌘O to open a PDF, or drag a PDF file into the window. Each document opens in its own tab."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Danh sách này có test canh (KeyboardShortcutHelpDriftTests): mỗi phím tắt
                // khai trong OpenPaperApp.swift phải xuất hiện ở đây, và không phím nào được
                // gán hai lệnh. Thiếu hoặc trùng là test đỏ — Help không thể trôi khỏi code
                // lần nữa (issue #9: từng có dòng ghi sai phím vì bảng viết tay).
                GroupBox(L("Keyboard Shortcuts")) {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow { Text(L("Open PDF…")); Text("⌘O") }
                        GridRow { Text(L("Save")); Text("⌘S") }
                        GridRow { Text(L("Save As…")); Text("⇧⌘S") }
                        GridRow { Text(L("Close Tab")); Text("⌘W") }
                        GridRow { Text(L("Print…")); Text("⌘P") }
                        GridRow { Text(L("Undo")); Text("⌘Z") }
                        GridRow { Text(L("Redo")); Text("⇧⌘Z") }
                        GridRow { Text(L("Find in PDF…")); Text("⌘F") }
                        GridRow { Text(L("Next Result")); Text("⌘G") }
                        GridRow { Text(L("Previous Result")); Text("⇧⌘G") }
                        GridRow { Text(L("Zoom In")); Text("⌘+") }
                        GridRow { Text(L("Zoom Out")); Text("⌘-") }
                        GridRow { Text(L("Fit Page")); Text("⌘0") }
                        GridRow { Text(L("Show/Hide Inspector")); Text("⌘I") }
                        GridRow { Text(L("Previous / Next Page")); Text("⌘[ / ⌘]") }
                        GridRow { Text(L("Go to Page…")); Text("⌥⌘G") }
                        GridRow { Text(L("Add Note")); Text("⇧⌘N") }
                        GridRow { Text(L("Add Text…")); Text("⇧⌘T") }
                        GridRow { Text(L("Insert Signature…")); Text("⌥⌘S") }
                        GridRow { Text(L("Highlight Selection")); Text("⇧⌘H") }
                        GridRow { Text(L("Redact Selection")); Text("⇧⌘X") }
                        GridRow { Text(L("Rotate Page Right")); Text("⇧⌘R") }
                        GridRow { Text(L("Rotate Page Left")); Text("⇧⌘L") }
                        GridRow { Text(L("Duplicate Current Page")); Text("⇧⌘D") }
                        GridRow { Text(L("Delete Current Page")); Text("⇧⌘⌫") }
                        GridRow { Text(L("Insert Pages from PDF…")); Text("⇧⌘I") }
                        GridRow { Text(L("Insert Image…")); Text("⌥⌘I") }
                        GridRow { Text(L("Export Current Page…")); Text("⇧⌘E") }
                        GridRow { Text(L("OCR Current Page…")); Text("⇧⌘O") }
                        GridRow { Text(L("OCR Region…")); Text("⇧⌘V") }
                        GridRow { Text(L("OCR Entire Document…")); Text("⇧⌘A") }
                        GridRow { Text(L("Validate PDF/A & PDF/UA…")); Text("⇧⌘K") }
                        GridRow { Text(L("Document Properties…")); Text("⇧⌘M") }
                        GridRow { Text(L("AZpdf Help")); Text("⇧⌘/") }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(L("Data Safety")) {
                    Text(L("AZpdf processes PDFs, passwords, and document history on your Mac. Redact is destructive: the page is rasterized to remove the original content."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(L("Digital Signatures and Plugins")) {
                    Text(L("Signing with a certificate exports a detached CMS/PKCS#7 .p7s file. Plugins run only locally after explicit permission; v1 does not enable arbitrary plugin execution."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(L("Local-first OCR")) {
                    Text(L("Choose OCR Current Page to have Vision recognize Vietnamese and English on your Mac. You can edit, copy, or export the .txt result; AZpdf does not modify the PDF itself."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(L("Support AZpdf")) {
                    VStack(spacing: 10) {
                        if let qrURL = Bundle.main.url(forResource: "donate-vietqr", withExtension: "jpg"),
                           let qrImage = NSImage(contentsOf: qrURL) {
                            Image(nsImage: qrImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Link(L("Support online via Ko-fi"), destination: AZpdfLinks.koFi)
                    }
                    .frame(maxWidth: .infinity)
                }
                Link(L("Source code and development guide"), destination: AZpdfLinks.repository)
            }
            .padding(24)
        }
        .frame(width: 620, height: 500)
    }
}
