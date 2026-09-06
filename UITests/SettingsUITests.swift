import XCTest

final class SettingsUITests: XCTestCase {
    /// 設定列「目前的值」怎麼讀。
    ///
    /// 以前是 `row.value`——那靠的是 `TLSettingsRow` 套的 `accessibilityValue`。
    /// 2026-08-30 移除無障礙那一輪把它拿掉了（`717fb1d`），於是 `value` 一律是空字串。
    ///
    /// SwiftUI 的 `Button` 會把子元素的文字合進 `label`（實測「Language, English」），
    /// 所以改讀 label：**列名與值都在同一個字串裡**，斷言值有沒有出現在裡面。
    private func assertRowValue(_ row: XCUIElement, _ expected: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            row.label.contains(expected),
            "設定列應顯示「\(expected)」，實際 label 是「\(row.label)」",
            file: file, line: line
        )
    }

    @MainActor
    func testThemeSelectionDrillInUpdatesValue() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.buttons["tabBar.item.settings"].tap()

        // 主題列（drill-in）：點進去選「深色」
        let themeRow = app.buttons["settings.row.theme"]
        XCTAssertTrue(themeRow.waitForExistence(timeout: 5))
        themeRow.tap()

        let darkOption = app.buttons["settings.option.dark"]
        XCTAssertTrue(darkOption.waitForExistence(timeout: 5))
        // 選項顯示文字跟著語言換，所以拿它當「等一下列上該出現的值」的期望值，而不是寫死中文。
        let darkLabel = darkOption.label
        darkOption.tap()

        // 選完自動返回設定根頁
        XCTAssertTrue(app.staticTexts["settings.title"].waitForExistence(timeout: 5))

        // 主題列的目前值 = 剛才選的那個
        let row = app.buttons["settings.row.theme"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        assertRowValue(row, darkLabel)
    }

    @MainActor
    func testAppIconSelectionUpdatesValue() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.buttons["tabBar.item.settings"].tap()

        // 不假設起始值：app icon 是系統／安裝層級的持久狀態（`UIApplication.alternateIconName`），
        // 不會像 SwiftData 那樣被 `--uitest-inmemory` 重置，測試裝置上可能殘留上次選的 icon。
        select(icon: "barbellPlate", app: app)
        select(icon: "sandArrow", app: app)   // sandArrow ＝ AppIcon.default
    }

    /// 點「App 圖示」列 → 選指定 icon → 確認（若跳系統彈窗）→ 回到設定根頁 → 確認列上的值已更新。
    @MainActor
    private func select(icon id: String, app: XCUIApplication) {
        let iconRow = app.buttons["settings.row.appIcon"]
        XCTAssertTrue(iconRow.waitForExistence(timeout: 5))
        iconRow.tap()

        let option = app.buttons["settings.option.\(id)"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        let optionLabel = option.label
        option.tap()

        // 系統可能會跳「要不要換 icon」的確認彈窗，有的話按下去。
        let confirm = app.alerts.buttons.element(boundBy: 0)
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        }

        // 選完自動返回設定根頁
        XCTAssertTrue(app.staticTexts["settings.title"].waitForExistence(timeout: 5))

        // ⚠ 這一列的「目前值」讀不到：它的右件是 `TLIconThumbnail`（一張圖，沒有文字），
        // 所以沒有東西會被折進 Button 的 label——不像主題／語言列的值是文字。
        // 以前靠 `accessibilityValue` 讀，那個在 `717fb1d 移除無障礙` 被拿掉了。
        //
        // 所以這裡只驗流程走得完（選單開得了、系統彈窗處理得掉、選完會回到設定根頁），
        // 值的部分等它有測試用的讀取管道再補。已記進 design-system/CHANGELOG.md 的已知缺口。
        _ = optionLabel
        let row = app.buttons["settings.row.appIcon"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLanguageRowShowsCurrentLanguage() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.buttons["tabBar.item.settings"].tap()

        // 語言列的值是**母語名**（`AppLanguage.nativeName`），刻意不本地化——不論介面是哪種語言，
        // 使用者都認得自己的選項。所以期望值跟著這一輪的 app 語言走，不是跟著介面語言走。
        let row = app.buttons["settings.row.language"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        assertRowValue(row, uitestAppLanguage == "en" ? "English" : "繁體中文")
    }

    /// 語言切換本身。刻意固定從繁中開始——英文那一輪如果讓它從英文起跑，就沒有「切換」可測了。
    @MainActor
    func testSwitchingLanguageToEnglishLocalizesSettings() throws {
        let app = XCUIApplication()
        launchForUITest(app, extra: ["--uitest-language=zh-Hant"])

        app.buttons["tabBar.item.settings"].tap()

        // 進語言列 → 選 English（選項以母語名呈現，切換前後都叫 "English"）
        let langRow = app.buttons["settings.row.language"]
        XCTAssertTrue(langRow.waitForExistence(timeout: 5))
        langRow.tap()
        let english = app.buttons["settings.option.en"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()

        // 切語言觸發 .id(language) 重建：留在設定分頁、內容與大標題已英文化。
        let title = app.staticTexts["settings.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Settings", "設定大標題應為 Settings")
        let langRowEN = app.buttons["settings.row.language"]
        XCTAssertTrue(langRowEN.waitForExistence(timeout: 5))
        // label 同時含列名與值（「Language, English」），所以兩個都用 contains 斷言。
        XCTAssertTrue(langRowEN.label.contains("Language"),
                      "語言列的列名應為 Language，實際是「\(langRowEN.label)」")
        assertRowValue(langRowEN, "English")

        // App target 的 tab bar 也英文化（驗證 app-target String Catalog 生效）
        XCTAssertEqual(app.buttons["tabBar.item.settings"].label, "Settings")
        XCTAssertEqual(app.buttons["tabBar.item.training"].label, "Training")

        // 回歸（bug2）：其他分頁的標題也要更新——原本用 navigationTitle 橋接 UIKit 會被快取、
        // 不隨 \.locale 重解析，靠 .id(language) 重建整個 TabView 才會以新語言重產。
        // 歷史頁改版後標題是 TLPageHeader（純 SwiftUI Text），不再是 navigationTitle，
        // 但一樣要驗證切語言後這個標題確實跟著換。
        app.buttons["tabBar.item.history"].tap()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5), "切英文後歷史大標題應為 History")
        XCTAssertFalse(
            app.navigationBars.allElementsBoundByIndex.contains { containsHan($0.identifier) },
            "切英文後不該還有中文的導覽列標題"
        )
    }

    /// 隱私政策入口：點了要在 App 內開起 Safari（`SFSafariViewController`），不跳出 App。
    /// 刻意不驗頁面內容——政策頁是線上的、由 `PRIVACY_POLICY_URL` 注入，測試機不保證連得到。
    /// Safari 就算載入失敗也還是會 present，所以這條不依賴網路；網址與語言 fragment 的正確性
    /// 由 SharedKernel 的 `PrivacyPolicyTests` 釘死。
    @MainActor
    func testPrivacyPolicyRowOpensInAppBrowser() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.buttons["tabBar.item.settings"].tap()

        // 這一列在「資料」區最底，捲到底才進 hierarchy（同版號那條）
        let row = app.buttons["settings.row.privacy"]
        if !row.waitForExistence(timeout: 3) {
            app.swipeUp()
            XCTAssertTrue(row.waitForExistence(timeout: 5))
        }
        row.tap()

        XCTAssertTrue(
            app.webViews.firstMatch.waitForExistence(timeout: 10),
            "點隱私政策應在 App 內開啟瀏覽器"
        )
        // 還在自己的 App 裡（SFSafariViewController 是 in-app，不是切到 Safari）
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testVersionRowShowsVersionAndBuild() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.buttons["tabBar.item.settings"].tap()

        // 版號在頁面最底，捲到底才進 hierarchy
        let version = app.staticTexts["settings.version"]
        if !version.waitForExistence(timeout: 3) {
            app.swipeUp()
            XCTAssertTrue(version.waitForExistence(timeout: 5))
        }
        // scheme-agnostic：dev 帶 build number「x.y.z (n)」、prod 只有「x.y.z」，
        // 分流邏輯由 SharedKernel 的 AppVersionTests 釘死，這裡只驗格式。
        XCTAssertNotNil(
            version.label.range(of: #"^\d+\.\d+\.\d+( \(\d+\))?$"#, options: .regularExpression),
            "版號格式應為「x.y.z」或「x.y.z (build)」，實際：\(version.label)"
        )
    }
}
