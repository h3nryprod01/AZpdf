import SwiftUI

struct SettingsView: View {
    @AppStorage("showPageBreaks") private var showPageBreaks = true
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.system.rawValue
    @State private var pluginRegistry = PluginRegistry()

    var body: some View {
        // `.grouped` is what makes this read as a macOS Settings window:
        // section headers sit above their card. The plain Form style pulls
        // each header into the label column, so "Quyền riêng tư" rendered on
        // the same line as its first row. The manual .padding(24) fought that
        // layout as well and clipped the caption text.
        Form {
            Section(L("Language")) {
                Picker(L("Display language"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language.rawValue)
                    }
                }
                Text(L("Applies immediately — no restart needed."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L("Display")) {
                Toggle(L("Show gaps between pages"), isOn: $showPageBreaks)
            }

            Section(L("Privacy")) {
                LabeledContent(L("Document handling")) { Text(L("This Mac only")) }
                Text(L("AZpdf never uploads your PDFs, their contents, passwords, or your document history to any server."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L("Local plugins")) {
                // Bare count rather than a pluralized string: it needs no
                // .stringsdict entry per language, and matches how the
                // inspector reports counts.
                LabeledContent(L("Detected plugins")) { Text("\(pluginRegistry.plugins.count)") }
                Text(L("AZpdf only detects safe local manifests; v1 does not run executables. Built-in OCR still runs entirely on your Mac."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(L("Reload Plugins")) { pluginRegistry.reload() }
            }

            Section(L("Project")) {
                LabeledContent(L("License")) { Text("AGPL-3.0") }
                Link(L("Support on Ko-fi"), destination: AZpdfLinks.koFi)
            }
        }
        .formStyle(.grouped)
        // Sized to fit on a laptop screen rather than to fit all content:
        // the grouped Form scrolls, so a taller window would only push the
        // last section off the bottom of the display.
        .frame(width: 480, height: 520)
    }
}
