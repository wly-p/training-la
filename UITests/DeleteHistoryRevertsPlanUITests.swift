import XCTest

/// #2 迴歸：照課表訓練完成後刪除該場歷史紀錄 → 對應排課應還原為未完成
/// （訓練首頁重新出現「照課表開始」）。
final class DeleteHistoryRevertsPlanUITests: XCTestCase {
    @MainActor
    func testDeleteHistoryRevertsPlanStatus() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 動作庫：建動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap(); nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 課表：新增今天的排課「推日」含臥推
        app.tabBars.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap(); planName.typeText("推日")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 訓練：照課表開始 → 完成一組 → 結束存檔
        app.tabBars.buttons["訓練"].tap()
        let startFromPlan = app.buttons["照課表開始"]
        XCTAssertTrue(startFromPlan.waitForExistence(timeout: 5))
        startFromPlan.tap()
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        app.buttons["結束訓練"].tap()
        let saveButton = app.buttons["儲存並結束"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        app.buttons["💪"].firstMatch.tap()
        saveButton.tap()

        // 排課已 done → 訓練首頁不再有今日排課
        XCTAssertTrue(app.staticTexts["今天沒有排課"].waitForExistence(timeout: 5))

        // 歷史：刪除該場（含確認）
        app.tabBars.buttons["歷史"].tap()
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.buttons["workoutDetail.delete"].waitForExistence(timeout: 5))
        app.buttons["workoutDetail.delete"].tap()
        let confirm = app.alerts.buttons["刪除"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // 排課還原為未完成 → 訓練首頁又出現「照課表開始」
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["照課表開始"].waitForExistence(timeout: 5))
    }
}
