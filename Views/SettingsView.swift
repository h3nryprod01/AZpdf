import SwiftUI

struct SettingsView: View {
    @AppStorage("showPageBreaks") private var showPageBreaks = true
    var body: some View {
        Form {
            Toggle("Hiển thị khoảng cách giữa các trang", isOn: $showPageBreaks)
            LabeledContent("Giấy phép") { Text("AGPL-3.0 (dự kiến)") }
            Link("Buy Me a Coffee", destination: URL(string: "https://www.buymeacoffee.com/")!)
        }
        .padding(24).frame(width: 420)
    }
}
