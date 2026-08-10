import XCTest

/// `--uitest-today=` 真的有被吃進去嗎？
///
/// 其他所有測試餵的都是「當下的真實日期」（見 `UITestSupport`），所以就算 app 完全忽略
/// 這個參數，那些測試也照樣會綠 —— 等於整套機制沒有任何東西在守。這支刻意餵一個
/// 跟系統時鐘無關的日期，確認畫面真的照它走。
final class FixedTodayUITests: XCTestCase {
    /// 隨便挑的一天，只要不是「今天」就有鑑別力。2026-03-15 是星期日。
    private let pinned = DateComponents(year: 2026, month: 3, day: 15)

    @MainActor
    func testTrainingHeaderFollowsTheInjectedToday() throws {
        let app = XCUIApplication()
        // 日期與語言都自己指定（`extra` 排在最前面，會蓋過這一輪的預設）：
        // 這支要驗的是日期注入，不該被英文那一輪換掉語言而讓下面的期望字串失準。
        launchForUITest(app, extra: ["--uitest-today=2026-03-15", "--uitest-language=zh-Hant"])

        // 訓練頁 header 的 kicker：沒有任何計畫時就只有日期本身。
        // 期望值用跟 View 同一組 formatter 算，才不會綁死某個語系的寫法。
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hant")   // in-memory 模式固定 seed 繁中
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("M/d EEEE")
        let expected = formatter.string(from: Calendar(identifier: .gregorian).date(from: pinned)!)

        XCTAssertTrue(
            app.staticTexts[expected].waitForExistence(timeout: 10),
            "訓練頁 header 應該顯示注入的日期「\(expected)」，而不是系統時鐘的今天"
        )
    }
}
