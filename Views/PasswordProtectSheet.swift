import SwiftUI

struct PasswordProtectSheet: View {
    @Bindable var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Export Protected PDF")).font(.title3.weight(.semibold))
            Text(L("The new copy will require a password to open. The password is not saved."))
                .foregroundStyle(.secondary)
            SecureField(L("Password"), text: $store.exportPassword)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L("Choose Save Location…")) { store.savePasswordProtectedExport() }
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
