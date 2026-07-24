import XCTest
@testable import AZpdf

/// Proves the SwiftPM `.lproj` localization infrastructure actually works
/// under `swift build`/`swift test` CLI (String Catalog `.xcstrings` does
/// not — see plan.md "Rủi ro hạ tầng"). Locale-specific assertions load each
/// `.lproj` directly via `Bundle(url:)` instead of going through `L(_:)`'s
/// automatic locale selection, because the *process's* preferred
/// localization is not deterministic across CI machines — only the on-disk
/// content and the bundle's declared localizations are.
final class LocalizationTests: XCTestCase {
    func testBundleDeclaresEnglishAndVietnamese() {
        let declared = Set(localizationBundle.localizations)
        XCTAssertTrue(declared.isSuperset(of: ["en", "vi"]), "expected en+vi, got \(declared)")
    }

    func testEnglishLocaleReturnsEnglishStrings() throws {
        let bundle = try lprojBundle("en")
        XCTAssertEqual(bundle.localizedString(forKey: "Open PDF", value: nil, table: nil), "Open PDF")
        XCTAssertEqual(bundle.localizedString(forKey: "Cancel", value: nil, table: nil), "Cancel")
    }

    func testVietnameseLocaleReturnsVietnameseStrings() throws {
        let bundle = try lprojBundle("vi")
        XCTAssertEqual(bundle.localizedString(forKey: "Open PDF", value: nil, table: nil), "Mở PDF")
        XCTAssertEqual(bundle.localizedString(forKey: "Cancel", value: nil, table: nil), "Hủy")
    }

    // Every key written by hand in en must have a vi counterpart and vice
    // versa, or an entire locale silently falls back to key text for that
    // string. Reading the raw plist catches a typo'd/missing key that a
    // build would never flag.
    func testEnglishAndVietnameseStringsHaveTheSameKeys() throws {
        let enKeys = try stringsKeys("en")
        let viKeys = try stringsKeys("vi")
        XCTAssertEqual(enKeys, viKeys, "en/vi Localizable.strings must declare the same key set")
        XCTAssertFalse(enKeys.isEmpty)
    }

    // Exercises the actual helper every call site uses (as opposed to the
    // Bundle(url:) bypass above), so a broken `localizationBundle` wiring
    // fails here even though its result is locale-dependent.
    func testHelperReturnsNonEmptyLocalizedStrings() {
        XCTAssertFalse(L("Open PDF").isEmpty)
        XCTAssertFalse(L("Cancel").isEmpty)
    }

    // MARK: - Helpers

    private func lprojBundle(_ locale: String) throws -> Bundle {
        let url = localizationBundle.bundleURL.appendingPathComponent("\(locale).lproj")
        return try XCTUnwrap(Bundle(url: url), "\(locale).lproj not found under \(localizationBundle.bundleURL)")
    }

    private func stringsKeys(_ locale: String) throws -> Set<String> {
        let bundle = try lprojBundle(locale)
        let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return Set(dict.keys)
    }
}

/// The Settings language picker pins one language regardless of what macOS is
/// set to. Without this the picker would silently do nothing on a Mac whose
/// system language already differs.
final class AppLanguageOverrideTests: XCTestCase {
    private func withLanguage(_ language: AppLanguage, _ body: () -> Void) {
        let previous = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: AppLanguage.storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
            }
        }
        body()
    }

    func testPinningEnglishReturnsEnglishRegardlessOfSystemLocale() {
        withLanguage(.english) {
            XCTAssertEqual(L("Privacy"), "Privacy")
            XCTAssertEqual(L("This Mac only"), "This Mac only")
        }
    }

    func testPinningVietnameseReturnsVietnameseRegardlessOfSystemLocale() {
        withLanguage(.vietnamese) {
            XCTAssertEqual(L("Privacy"), "Quyền riêng tư")
            XCTAssertEqual(L("This Mac only"), "Chỉ trên máy này")
        }
    }

    // The two pinned languages must actually differ — if the override silently
    // fell back to one bundle, both tests above could still pass on a machine
    // whose system language happened to match.
    func testPinnedLanguagesResolveToDifferentBundles() {
        var english = ""
        var vietnamese = ""
        withLanguage(.english) { english = L("Privacy") }
        withLanguage(.vietnamese) { vietnamese = L("Privacy") }
        XCTAssertNotEqual(english, vietnamese)
    }

    func testSystemChoiceUsesTheWholeResourceBundle() {
        XCTAssertEqual(localizationBundle(for: .system).bundlePath, localizationBundle.bundlePath)
        XCTAssertNotEqual(localizationBundle(for: .english).bundlePath, localizationBundle.bundlePath)
    }

    func testUnsetPreferenceFollowsTheSystem() {
        UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
        XCTAssertEqual(AppLanguage.current, .system)
    }

    // Proves the .stringsdict pipeline resolves under the pinned language, not
    // just the .strings file. English inflects plurals and Vietnamese does not,
    // so a broken locale pin shows up as "1 pages". Nothing consumes this key
    // in the UI yet — it is pinned here so the next sweep can rely on plurals
    // working instead of discovering they never did.
    func testPluralsResolveUnderThePinnedLanguage() {
        withLanguage(.english) {
            XCTAssertEqual(L("\(1) pages"), "1 page")
            XCTAssertEqual(L("\(3) pages"), "3 pages")
        }
        withLanguage(.vietnamese) {
            XCTAssertEqual(L("\(1) pages"), "1 trang")
            XCTAssertEqual(L("\(3) pages"), "3 trang")
        }
    }

    /// A language is listed in its own language so someone who cannot read the
    /// current UI can still find theirs.
    func testConcreteLanguagesAreNamedInTheirOwnLanguage() {
        XCTAssertEqual(AppLanguage.english.label, "English")
        XCTAssertEqual(AppLanguage.vietnamese.label, "Tiếng Việt")
    }
}
