import XCTest
@testable import Search

final class LocalizationTests: XCTestCase {
    func testSystemLanguageAndExplicitOverrides() {
        XCTAssertEqual(InterfaceLanguage.resolve(.system, preferred: ["zh-Hans-CN", "en"]), "zh-Hans")
        XCTAssertEqual(InterfaceLanguage.resolve(.system, preferred: ["en-US", "zh-Hans"]), "en")
        XCTAssertEqual(InterfaceLanguage.resolve(.system, preferred: ["fr"]), "en")
        XCTAssertEqual(InterfaceLanguage.resolve(.english, preferred: ["zh-Hans"]), "en")
        XCTAssertEqual(InterfaceLanguage.resolve(.simplifiedChinese, preferred: ["en"]), "zh-Hans")
    }

    @MainActor
    func testSelectionPersistsWithoutChangingOtherPreferences() {
        let settings = LanguageSettings.shared
        let previous = settings.selection
        let world = Store.world ?? "test"
        let domain = world == "test" ? "com.officecommun.search.test" : "com.officecommun.search.test.\(world)"
        let oldAppleLanguages = Store.settings.persistentDomain(forName: domain)?["AppleLanguages"]
        let oldAppearance = Store.settings.string(forKey: "look")
        defer {
            settings.selection = previous
            if let oldAppleLanguages { Store.settings.set(oldAppleLanguages, forKey: "AppleLanguages") }
            else { Store.settings.removeObject(forKey: "AppleLanguages") }
        }
        settings.selection = .english
        XCTAssertEqual(Store.settings.string(forKey: "interface.language"), "en")
        XCTAssertEqual(Store.settings.stringArray(forKey: "AppleLanguages"), ["en"])
        settings.selection = .simplifiedChinese
        XCTAssertEqual(Store.settings.stringArray(forKey: "AppleLanguages"), ["zh-Hans"])
        settings.selection = .system
        // object(forKey:) falls back to macOS's global AppleLanguages after removal.
        XCTAssertNil(Store.settings.persistentDomain(forName: domain)?["AppleLanguages"])
        XCTAssertEqual(Store.settings.string(forKey: "look"), oldAppearance)
    }

    func testBothLanguagesAndFallback() {
        XCTAssertEqual(L10n.render("language.title", language: "en"), "Language")
        XCTAssertEqual(L10n.render("language.title", language: "zh-Hans"), "界面语言")
        XCTAssertEqual(L10n.render("language.title", language: "unknown"), "Language")
        XCTAssertEqual(L10n.render("missing", language: "en"), "missing")
        for (key, entry) in L10n.translations {
            XCTAssertNotNil(entry["en"], key)
            XCTAssertNotNil(entry["zh-Hans"], key)
        }
    }

    func testUserContentIsNotReinterpretedAsTranslationPlaceholders() {
        let name = "{1} 中文 ' \" \\"
        // Both placeholders in this message take user content.
        let key = L10n.translations.first { $0.value["en"] == "{0} wants to open {1}." }!.key
        XCTAssertEqual(L10n.render(key, language: "en", arguments: [name, "Mail"]), "\(name) wants to open Mail.")
        XCTAssertEqual(L10n.render(key, language: "zh-Hans", arguments: [name, "Mail"]), "\(name) 请求打开 Mail。")
    }
}
