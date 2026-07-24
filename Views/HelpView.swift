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
                GroupBox(L("Keyboard Shortcuts")) {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow { Text(L("Open PDF")); Text("⌘O") }
                        GridRow { Text(L("Save")); Text("⌘S") }
                        GridRow { Text(L("Print Document")); Text("⌘P") }
                        GridRow { Text(L("Previous / Next Page")); Text("⌘[ / ⌘]") }
                        GridRow { Text(L("Note / Highlight")); Text("⇧⌘N / ⇧⌘H") }
                        GridRow { Text(L("Handwritten Signature")); Text("⇧⌘G") }
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
