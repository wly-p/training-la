import Foundation
import Testing

@testable import SharedKernel

struct PrivacyPolicyTests {
    @Test func readsURLFromInfoDictionary() {
        let url = PrivacyPolicy.baseURL(infoDictionary: ["PrivacyPolicyURL": "https://example.com/privacy.html"])
        #expect(url?.absoluteString == "https://example.com/privacy.html")
    }

    @Test func missingKeyGivesNil() {
        #expect(PrivacyPolicy.baseURL(infoDictionary: [:]) == nil)
    }

    /// xcconfig 的值沒設好時最常見的樣子就是空字串，不能讓它變成一個開不起來的入口。
    @Test func blankValueGivesNil() {
        #expect(PrivacyPolicy.baseURL(infoDictionary: ["PrivacyPolicyURL": "   "]) == nil)
    }

    /// xcconfig 把 `//` 當註解，`https://…` 若沒繞開會被截成 `https:`——這正是那個坑的形狀。
    @Test func schemeOnlyValueGivesNil() {
        #expect(PrivacyPolicy.baseURL(infoDictionary: ["PrivacyPolicyURL": "https:"]) == nil)
    }

    @Test func appLanguageBecomesFragment() {
        let base = URL(string: "https://example.com/privacy.html")!
        #expect(PrivacyPolicy.localizedURL(base: base, language: .zhHant)
            .absoluteString == "https://example.com/privacy.html#zh-Hant")
        #expect(PrivacyPolicy.localizedURL(base: base, language: .en)
            .absoluteString == "https://example.com/privacy.html#en")
    }

    /// 換語言後再開一次不能疊出兩個 `#`。
    @Test func existingFragmentIsReplacedNotAppended() {
        let base = URL(string: "https://example.com/privacy.html#zh-Hant")!
        #expect(PrivacyPolicy.localizedURL(base: base, language: .en)
            .absoluteString == "https://example.com/privacy.html#en")
    }

    @Test func queryIsPreserved() {
        let base = URL(string: "https://example.com/privacy.html?v=2")!
        #expect(PrivacyPolicy.localizedURL(base: base, language: .en)
            .absoluteString == "https://example.com/privacy.html?v=2#en")
    }
}
