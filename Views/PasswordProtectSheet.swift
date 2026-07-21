import SwiftUI

struct PasswordProtectSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Xuất PDF được bảo vệ").font(.title3.weight(.semibold))
            Text("Bản sao mới sẽ yêu cầu mật khẩu để mở. Mật khẩu không được lưu lại.")
                .foregroundStyle(.secondary)
            SecureField("Mật khẩu", text: $store.exportPassword)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Chọn nơi lưu…") { store.savePasswordProtectedExport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.exportPassword.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(EscapeDismissInstaller { dismiss() })
    }
}
