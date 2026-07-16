import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().interpolation(.high).frame(width: 96, height: 96)
            Text("AZpdf").font(.title.weight(.bold))
            Text("Phiên bản \(version) • macOS 14+").foregroundStyle(.secondary)
            Text("Trình đọc và chỉnh sửa PDF local-first, miễn phí và mã nguồn mở.")
                .multilineTextAlignment(.center)
            Text("AGPL-3.0-only").font(.caption).foregroundStyle(.secondary)
            HStack {
                Link("GitHub", destination: AZpdfLinks.repository)
                Link("Ủng hộ qua Ko-fi", destination: AZpdfLinks.koFi)
            }
        }
        .padding(28)
        .frame(width: 400)
    }
}
