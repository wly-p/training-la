import XCTest

/// 休息結束提醒設定：Settings 顯示四個 toggle、預設值正確、可切換。
/// 同時作為新相依圖（Reminders 包接線）啟動不崩的煙霧測試。
final class RestReminderSettingsUITests: XCTestCase {
    @MainActor
    func testReminderTogglesRenderWithDefaultsAndToggle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.tabBars.buttons["設定"].tap()

        XCTAssertTrue(app.staticTexts["休息結束提醒（App 開著時）"].waitForExistence(timeout: 5))

        let popup = app.switches["彈窗"]
        let sound = app.switches["聲音"]
        let haptic = app.switches["震動"]
        let background = app.switches["背景通知"]
        XCTAssertTrue(popup.waitForExistence(timeout: 5))
        XCTAssertTrue(sound.exists)
        XCTAssertTrue(haptic.exists)
        XCTAssertTrue(background.exists)

        // 預設：彈窗 / 聲音 / 背景通知 開，震動 關
        XCTAssertEqual(popup.value as? String, "1")
        XCTAssertEqual(sound.value as? String, "1")
        XCTAssertEqual(background.value as? String, "1")
        XCTAssertEqual(haptic.value as? String, "0")

        // 可切換：開啟震動（點 cell 尾端的開關控制，避免點到標籤無效）
        haptic.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let turnedOn = NSPredicate(format: "value == %@", "1")
        expectation(for: turnedOn, evaluatedWith: haptic)
        waitForExpectations(timeout: 5)
    }
}
