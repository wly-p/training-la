import XCTest

final class SettingsUITests: XCTestCase {
    @MainActor
    func testThemeSelectionDrillInUpdatesValue() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.tabBars.buttons["設定"].tap()

        // 主題列（navigationLink picker）：點進去選「深色」
        let themeRow = app.buttons["主題"]
        XCTAssertTrue(themeRow.waitForExistence(timeout: 5))
        themeRow.tap()

        let darkOption = app.buttons["深色"]
        XCTAssertTrue(darkOption.waitForExistence(timeout: 5))
        darkOption.tap()

        // 確保回到設定根頁（不同 iOS 版本 navigationLink picker 選完不一定自動返回）
        let settingsNav = app.navigationBars["設定"]
        if !settingsNav.waitForExistence(timeout: 2) {
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(settingsNav.waitForExistence(timeout: 5))
        }

        // 主題列的目前值 = 深色
        let row = app.buttons["主題"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.value as? String, "深色")
    }

    @MainActor
    func testAppIconSelectionUpdatesValue() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.tabBars.buttons["設定"].tap()

        // 不假設起始值：app icon 是系統／安裝層級的持久狀態（`UIApplication.alternateIconName`），
        // 不會像 SwiftData 那樣被 `--uitest-inmemory` 重置，測試裝置上可能殘留上次選的 icon。
        select(icon: "槓片", app: app)
        select(icon: "預設", app: app)
    }

    /// 點「App 圖示」列 → 選指定 icon → 確認（若跳系統彈窗）→ 回到設定根頁 → 確認列上的值已更新。
    private func select(icon name: String, app: XCUIApplication) {
        let iconRow = app.buttons["App 圖示"]
        XCTAssertTrue(iconRow.waitForExistence(timeout: 5))
        iconRow.tap()

        let option = app.buttons[name]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()

        // 系統可能會跳「要不要換 icon」的確認彈窗，有的話按下去。
        let confirm = app.alerts.buttons.element(boundBy: 0)
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        }

        let settingsNav = app.navigationBars["設定"]
        if !settingsNav.waitForExistence(timeout: 2) {
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(settingsNav.waitForExistence(timeout: 5))
        }

        let row = app.buttons["App 圖示"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.value as? String, name)
    }

    @MainActor
    func testLanguageRowShowsCurrentLanguage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.tabBars.buttons["設定"].tap()

        // 語言列：navigationLink picker，值顯示目前語言的母語名（UI 測試固定 seed 繁中）
        let row = app.buttons["語言"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.value as? String, "繁體中文")
    }

    @MainActor
    func testSwitchingLanguageToEnglishLocalizesSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.tabBars.buttons["設定"].tap()

        // 進語言列 → 選 English（選項以母語名呈現，切換前後都叫 "English"）
        let langRow = app.buttons["語言"]
        XCTAssertTrue(langRow.waitForExistence(timeout: 5))
        langRow.tap()
        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()

        // 回設定根頁（此時標題已英文化為 "Settings"，不能再用「設定」定位）
        let settingsRoot = app.navigationBars["Settings"]
        if !settingsRoot.waitForExistence(timeout: 2) {
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(settingsRoot.waitForExistence(timeout: 5))
        }

        // Settings 內容已英文化：section header 與語言列標籤/值
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 5))
        let langRowEN = app.buttons["Language"]
        XCTAssertTrue(langRowEN.waitForExistence(timeout: 5))
        XCTAssertEqual(langRowEN.value as? String, "English")
    }

    @MainActor
    func testVersionRowShowsVersionAndBuild() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.tabBars.buttons["設定"].tap()

        // 「關於」在清單最底，List 是 lazy 的，可能要捲到底元素才會進 hierarchy
        let version = app.staticTexts["appVersion"]
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
