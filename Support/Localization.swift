import Foundation

/// The AZpdf target's own resource bundle. Exposed so tests can reference the
/// exact bundle `L(_:)` reads from — `Bundle.module` written inside a test
/// file would resolve to the *test target's* bundle instead, silently
/// missing every string in Resources/*.lproj.
let localizationBundle = Bundle.module

/// UI language. `.system` follows macOS; the others pin one language, so
/// someone whose Mac runs a third language can still read the app.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case vietnamese = "vi"

    var id: String { rawValue }

    static let storageKey = "appLanguage"

    /// Deliberately NOT localized for the concrete languages: each is written
    /// in its own language so a user who cannot read the current UI can still
    /// recognise theirs in the list.
    var label: String {
        switch self {
        case .system: L("Match macOS")
        case .english: "English" // i18n-exempt: a language names itself
        case .vietnamese: "Tiếng Việt" // i18n-exempt: a language names itself
        }
    }

    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppLanguage.init) ?? .system
    }
}

/// Bundle `L(_:)` reads from: the whole resource bundle when following the
/// system (so macOS picks the best match), or the single `.lproj` the user
/// pinned. Resolved per call rather than cached — `Bundle(path:)` returns the
/// same instance for a path it has already loaded, so this is a dictionary
/// lookup, and caching it ourselves would keep serving the old language after
/// the user switches.
func localizationBundle(for language: AppLanguage) -> Bundle {
    guard language != .system,
          let path = localizationBundle.path(forResource: language.rawValue, ofType: "lproj"),
          let pinned = Bundle(path: path) else { return localizationBundle }
    return pinned
}

/// Looks up `key` in `Resources/en.lproj` / `Resources/vi.lproj`, falling
/// back to the English identity value if no translation exists for the
/// active locale. `vi` is preserved verbatim from the strings that shipped
/// before localization existed; `en` is written by hand per Apple HIG.
func L(_ key: String.LocalizationValue) -> String {
    let language = AppLanguage.current
    return String(
        localized: key,
        bundle: localizationBundle(for: language),
        // Pinning the locale too: the bundle alone still lets Foundation fall
        // back to the process locale for plural rules in `.stringsdict`, so a
        // user on a Vietnamese Mac who picks English would read "1 pages".
        // Not provable by the test suite here — the plural test only fails on
        // a host whose own locale disagrees with the pinned one, and this
        // machine's does not. Kept because it is correct, not because it is
        // covered.
        locale: language == .system ? .current : Locale(identifier: language.rawValue)
    )
}
