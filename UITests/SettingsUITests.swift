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
    func testEnvironmentBadgeReflectsBuildConfig() throws {
        // scheme-agnostic：dev/prod scheme 下都該顯示對應環境的小標。
        // 哪個 config 對到哪組值，已由 build 端的 Info.plist 檢查釘死。
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.tabBars.buttons["設定"].tap()
        let badge = app.staticTexts["environmentBadge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        let valid = ["dev · training-la-api-dev.wly.lol", "prod · training-la-api.wly.lol"]
        XCTAssertTrue(valid.contains(badge.label), "unexpected badge: \(badge.label)")
    }
}
