import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().interpolation(.high).frame(width: 96, height: 96)
            Text("AZpdf").font(.title.weight(.bold))
            Text(L("Version \(version) • macOS 14+")).foregroundStyle(.secondary)
            Text(L("A local-first, free, and open-source PDF reader and editor."))
                .multilineTextAlignment(.center)
            Text("AGPL-3.0-only").font(.caption).foregroundStyle(.secondary)
            HStack {
                Link("GitHub", destination: AZpdfLinks.repository)
                Link(L("Support on Ko-fi"), destination: AZpdfLinks.koFi)
            }
        }
        .padding(28)
        .frame(width: 400)
    }
}
