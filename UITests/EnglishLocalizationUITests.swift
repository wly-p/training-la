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
    /// 分頁列由左到右：訓練 / 課表 / 動作庫 / 歷史 / 設定。用索引而非標籤，才不依賴語言。
    private let tabCount = 5

    @MainActor
    func testNoChineseTextInEnglishLocale() throws {
        let app = XCUIApplication()
        // 乾淨的 store（畫面上不會有使用者輸入的中文資料）＋ app 語言強制英文（裝置維持繁中）
        app.launchArguments = ["--uitest-inmemory", "--uitest-language=en"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "找不到分頁列")

        var offenders: [String] = []

        for index in 0..<tabCount {
            let tab = tabBar.buttons.element(boundBy: index)
            guard tab.exists else { continue }
            tab.tap()
            // 換頁後給 SwiftUI 一點時間重繪，否則抓到的是上一頁的殘影。
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 5)

            for label in visibleLabels(in: app) where Self.containsHan(label) {
                offenders.append("[分頁 \(index)] \(label)")
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "英文語系下仍出現中文（共 \(offenders.count) 處）：\n" + offenders.prefix(30).joined(separator: "\n")
        )
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

    /// 是否含 CJK 統一表意文字（含擴充 A）。標點與英數不算。
    private static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
        }
    }
}
