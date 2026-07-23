import Testing
import SharedKernel
@testable import RemindersKit

/// 註：swift test（SwiftPM CLI）不編譯 String Catalog，`AppLanguage.localizedString` 在這裡查不到
/// 翻譯、回退成原始 key（見 fallback 那條），所以這裡只驗「回傳非空、兩個 key 不同」這類跟 catalog
/// 內容無關的結構；實際中英文字串已用 xcodebuild -testPlan UnitTests 手動決定性驗證過
/// （zh="休息結束"/"休息時間到了，準備下一組。"、en="Rest Over"/"Time's up — get ready for your next set."），
/// 跟 Plan/Training 用的是同一個 AppLanguage.localizedString 機制。
struct RemindersKitLocalizationTests {
    @Test func restOverKeysResolveToNonEmptyDistinctStrings() {
        let title = AppLanguage.zhHant.localizedString("reminders.restOver.title", bundle: .module)
        let body = AppLanguage.zhHant.localizedString("reminders.restOver.body", bundle: .module)
        #expect(!title.isEmpty)
        #expect(!body.isEmpty)
        #expect(title != body)
    }
}
