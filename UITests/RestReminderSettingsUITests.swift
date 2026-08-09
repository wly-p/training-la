import XCTest

/// 休息結束提醒設定：前景（彈窗/聲音）＋背景（背景通知）三個 toggle、預設值正確、可切換。
/// 同時作為新相依圖（Reminders 包接線）啟動不崩的煙霧測試。
final class RestReminderSettingsUITests: XCTestCase {
    @MainActor
    func testReminderTogglesRenderWithDefaultsAndToggle() throws {
        let app = XCUIApplication()
        app.launchArguments = uitestLaunchArguments()
        app.launch()

        app.buttons["設定"].tap()

        // 改版後前景／背景兩區併成單一「休息結束提醒」群組（三個開關同組）。
        XCTAssertTrue(app.staticTexts["休息結束提醒"].waitForExistence(timeout: 5))

        let popup = app.switches["彈窗"]
        let sound = app.switches["聲音"]
        let background = app.switches["背景通知"]
        XCTAssertTrue(popup.waitForExistence(timeout: 5))
        XCTAssertTrue(sound.exists)
        XCTAssertTrue(background.exists)
        XCTAssertFalse(app.switches["震動"].exists) // 震動設定已移除（跟隨系統，App 控不了）

        // 預設：全開
        XCTAssertEqual(popup.value as? String, "1")
        XCTAssertEqual(sound.value as? String, "1")
        XCTAssertEqual(background.value as? String, "1")

        // 可切換：關掉背景通知（點 cell 尾端的開關控制，避免點到標籤無效）。
        // 先捲進可視範圍——設定頁的外觀組後來多了「重量調整級距」「休息時間級距」兩列，
        // 提醒區被推到摺線下，而座標點擊不會自動捲動（exists／value 在畫面外仍讀得到，
        // 所以前面的斷言不會發現，只有點擊會落空）。
        var scrollAttempts = 0
        while !background.isHittable, scrollAttempts < 6 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(background.isHittable, "「背景通知」開關捲不進可視範圍")
        background.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let turnedOff = NSPredicate(format: "value == %@", "0")
        expectation(for: turnedOff, evaluatedWith: background)
        waitForExpectations(timeout: 5)
    }
}
