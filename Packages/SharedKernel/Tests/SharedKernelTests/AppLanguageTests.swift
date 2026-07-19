import Foundation
import Testing

@testable import SharedKernel

struct AppLanguageTests {
    // MARK: - resolve（分支接線）

    @Test func storedPreferenceWinsOverSystem() {
        // 設定有值 → 不看系統（存繁中、系統英文 → 繁中）
        #expect(LanguageResolver.resolve(stored: .zhHant, systemPreferred: ["en-US"]) == .zhHant)
        // 反向：存英文、系統繁中 → 英文
        #expect(LanguageResolver.resolve(stored: .en, systemPreferred: ["zh-Hant-TW"]) == .en)
    }

    @Test func firstLaunchPicksChineseSystem() {
        #expect(LanguageResolver.resolve(stored: nil, systemPreferred: ["zh-Hant-TW", "en-US"]) == .zhHant)
    }

    @Test func firstLaunchPicksEnglishSystem() {
        #expect(LanguageResolver.resolve(stored: nil, systemPreferred: ["en-US"]) == .en)
    }

    @Test func firstLaunchTakesFirstSupportedInSystemOrder() {
        // 系統第一偏好英文、第二繁中 → 取英文
        #expect(LanguageResolver.resolve(stored: nil, systemPreferred: ["en-GB", "zh-Hant-TW"]) == .en)
    }

    @Test func firstLaunchFallsBackWhenSystemUnsupported() {
        // 都不支援（法/德）→ fallback（繁中）
        #expect(LanguageResolver.resolve(stored: nil, systemPreferred: ["fr-FR", "de-DE"]) == .fallback)
    }

    @Test func emptySystemFallsBack() {
        #expect(LanguageResolver.resolve(stored: nil, systemPreferred: []) == .fallback)
    }

    // MARK: - match（多元素，證明比對邏輯不綁「目前只有幾個語言」）

    @Test func matchExact() {
        #expect(LanguageResolver.match(languageID: "en", supported: ["zh-Hant", "en"]) == "en")
    }

    @Test func matchScriptOrRegionSuffix() {
        #expect(LanguageResolver.match(languageID: "zh-Hant-TW", supported: ["zh-Hant", "en"]) == "zh-Hant")
        #expect(LanguageResolver.match(languageID: "en-US", supported: ["zh-Hant", "en"]) == "en")
    }

    @Test func matchMissReturnsNil() {
        #expect(LanguageResolver.match(languageID: "fr-FR", supported: ["zh-Hant", "en"]) == nil)
    }

    @Test func matchTakesFirstBySupportedOrder() {
        #expect(LanguageResolver.match(languageID: "zh-Hant-TW", supported: ["en", "zh-Hant"]) == "zh-Hant")
    }

    @Test func matchDoesNotMatchOnBareLanguagePrefix() {
        // "zh-Hant" 不該去命中純 "zh"（避免把繁中誤配到未來的簡中等）
        #expect(LanguageResolver.match(languageID: "zh", supported: ["zh-Hant"]) == nil)
    }

    // MARK: - store round-trip

    @Test func storeStartsEmptyThenPersists() {
        let store = InMemoryLanguageStore()
        #expect(store.load() == nil)
        store.save(.zhHant)
        #expect(store.load() == .zhHant)
    }

    // MARK: - locale 映射

    @Test func localeCarriesLanguageAndScript() {
        let locale = AppLanguage.zhHant.locale
        #expect(locale.language.languageCode?.identifier == "zh")
        #expect(locale.language.script?.identifier == "Hant")
    }

    @Test func initFromLocaleRoundTrips() {
        // 這正是根部注入的 locale（AppLanguage.locale）反解回來，要能還原成同一個 case
        #expect(AppLanguage(locale: AppLanguage.zhHant.locale) == .zhHant)
        #expect(AppLanguage(locale: AppLanguage.en.locale) == .en)
    }

    @Test func initFromUnsupportedLocaleFallsBack() {
        #expect(AppLanguage(locale: Locale(identifier: "fr-FR")) == .fallback)
    }

    // MARK: - localizedString（機制驗證見對應 package 的 xcodebuild UITest；這裡只驗
    // 找不到 lproj／key 時的保底行為，不需要真的編出 String Catalog）

    @Test func localizedStringFallsBackToKeyWhenBundleHasNoTranslation() {
        // Bundle.main 沒有 "not.a.real.key" 這個 table，Foundation 的慣例是原樣回傳 key
        let result = AppLanguage.en.localizedString("not.a.real.key", bundle: .main)
        #expect(result == "not.a.real.key")
    }
}
