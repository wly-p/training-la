import XCTest

final class RestTimerUITests: XCTestCase {
    @MainActor
    func testRestCountdownPopsUpAfterCompletingSet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 動作庫建一個動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 課表：新增排課，休息設 2 秒
        app.tabBars.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("休息測試")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()

        let restField = app.textFields["秒（可留空）"]
        XCTAssertTrue(restField.waitForExistence(timeout: 5))
        restField.tap()
        restField.typeText("2") // 空欄位，直接輸入 2 秒
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["休息測試"].waitForExistence(timeout: 5))

        // 照課表訓練，完成一組
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["照課表開始"].waitForExistence(timeout: 5))
        app.buttons["照課表開始"].tap()
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        // 休息倒數條出現
        XCTAssertTrue(app.staticTexts["休息中"].waitForExistence(timeout: 3))

        // 時間到 → 彈窗
        let popup = app.staticTexts["休息結束"]
        XCTAssertTrue(popup.waitForExistence(timeout: 8))
        app.buttons["開始下一組"].tap()

        // 彈窗關閉、可繼續記下一組
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["休息結束"].exists)
    }
}
