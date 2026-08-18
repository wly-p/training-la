import XCTest

/// 英文語系的 smoke test：走過五個分頁，斷言畫面上**不出現任何中文字元**。
///
/// 為什麼需要這個：app 的語言切換走 SwiftUI 的 `\.locale` environment，只有 `Text(key, bundle:)`
/// 吃得到。`String(localized:)` 是立即求值、只認 process locale，所以在「手機語系 ≠ app 語言」時
/// 會整片不跟著切。本機模擬器語系一向與 app 語言一致，這類 bug 看不出來——只有真的用英文跑才會現形。
///
/// 為什麼是獨立一支而不是讓既有 22 個測試也跑英文：那些測試靠中文標籤查元素
/// （`app.buttons["動作庫"]`），共 460＋ 處，全部要改成 accessibility identifier 才可能跑英文。
/// 這支只用 identifier 與索引定位，跟語言無關。
///
/// ⚠️ 跑的組合是「**裝置語系繁中 ＋ app 語言英文**」，不是兩邊都英文。
/// 兩邊都設英文的話 `String(localized:)` 也會回英文，反而把 bug 藏起來——正是這個盲點讓它一路活到現在。
/// 所以本測試在預設的 `zh-Hant` configuration 下跑，靠 `--uitest-language=en` 只改 app 自己的語言偏好。
final class EnglishLocalizationUITests: XCTestCase {
    /// 分頁列由左到右。用 identifier 而非標籤，才不依賴語言（見 ARCHITECTURE.md 的命名規範）。
    private let tabs = ["training", "exercises", "plan", "history", "settings"]

    @MainActor
    func testNoChineseTextInEnglishLocale() throws {
        let app = XCUIApplication()
        // 乾淨的 store（畫面上不會有使用者輸入的中文資料）＋ app 語言強制英文（裝置維持繁中）
        launchForUITest(app, extra: ["--uitest-language=en"])

        var offenders: [String] = []
        var previous: [String] = []

        for name in tabs {
            // 用自訂分頁列的 identifier，不用 app.tabBars——原生分頁列被隱藏了但仍在無障礙樹裡，
            // 點它不會真的換頁（這正是本測試原本漏掉整個課表頁的原因）。
            let tab = app.buttons["tabBar.item.\(name)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "找不到分頁 \(name)")
            tab.tap()

            let labels = waitForContentChange(in: app, from: previous)
            XCTAssertNotEqual(
                labels, previous,
                "分頁 \(name) 的內容與前一頁相同——很可能是還沒換頁就取值了，這一頁等於沒測到"
            )
            previous = labels

            for label in labels where containsHan(label) {
                offenders.append("[\(name)] \(label)")
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "英文語系下仍出現中文（共 \(offenders.count) 處）：\n" + offenders.prefix(30).joined(separator: "\n")
        )
    }

    /// 等到畫面內容真的換掉為止，回傳新一頁的文字。
    ///
    /// 不能只等「有 staticText 存在」——上一頁的 staticText 本來就在，那種等待會立刻通過，
    /// 於是取到的是舊畫面。這個 bug 讓本測試有一整頁（課表）從來沒被真正檢查過，
    /// 而漏掉的正是那一頁上的中文星期。所以改成等「內容與前一頁不同」。
    @MainActor
    private func waitForContentChange(in app: XCUIApplication, from previous: [String]) -> [String] {
        let deadline = Date().addingTimeInterval(5)
        var labels = visibleLabels(in: app)
        while labels == previous, Date() < deadline {
            usleep(200_000)
            labels = visibleLabels(in: app)
        }
        return labels
    }

    /// 畫面上所有可見的文字：靜態文字 ＋ 按鈕標題 ＋ 導覽列標題。
    @MainActor
    private func visibleLabels(in app: XCUIApplication) -> [String] {
        let sources = [app.staticTexts, app.buttons, app.navigationBars.staticTexts]
        return sources.flatMap { query in
            query.allElementsBoundByIndex
                .filter(\.exists)
                .map(\.label)
        }
    }

}
