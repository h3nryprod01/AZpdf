import SwiftUI

struct SettingsView: View {
    @AppStorage("showPageBreaks") private var showPageBreaks = true
    @State private var pluginRegistry = PluginRegistry()

    var body: some View {
        Form {
            Section("Hiển thị") {
                Toggle("Hiển thị khoảng cách giữa các trang", isOn: $showPageBreaks)
            }
            Section("Quyền riêng tư") {
                LabeledContent("Xử lý tài liệu") { Text("Chỉ trên máy này") }
                Text("AZpdf không tải PDF, nội dung, mật khẩu hoặc lịch sử tài liệu lên máy chủ.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Plugin cục bộ") {
                LabeledContent("Đã phát hiện") { Text("\(pluginRegistry.plugins.count) plugin") }
                Text("AZpdf chỉ phát hiện manifest cục bộ an toàn; v1 chưa chạy executable. OCR tích hợp vẫn hoạt động hoàn toàn trên máy.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Tải lại plugin") { pluginRegistry.reload() }
            }
            Section("Dự án") {
                LabeledContent("Giấy phép") { Text("AGPL-3.0") }
                Link("Ủng hộ qua Ko-fi", destination: AZpdfLinks.koFi)
            }
        }
        .padding(24).frame(width: 420)
    }
}
