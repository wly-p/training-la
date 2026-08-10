import XCTest

/// #2 迴歸：照課表訓練完成後刪除該場歷史紀錄 → 對應排課應還原為未完成
/// （訓練首頁重新出現「開始」）。
final class DeleteHistoryRevertsPlanUITests: XCTestCase {
    @MainActor
    func testDeleteHistoryRevertsPlanStatus() throws {
        let app = XCUIApplication()
        app.launchArguments = uitestLaunchArguments()
        app.launch()

        // 動作庫：建動作
        app.buttons["動作庫"].tap()
        app.buttons["library.add"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap(); nameField.typeText("測試臥推")
        app.buttons["儲存"].tap()
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        app.clearExerciseListSearch()

        // 課表：新增今天的排課「推日」含測試臥推
        app.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap(); planName.typeText("推日")
        app.buttons["加入動作"].tap()
        app.pickExercise("測試臥推")
        app.buttons["加入 1 個動作"].tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 訓練：開始 → 完成一組 → 結束存檔
        app.buttons["訓練"].tap()
        let startFromPlan = app.buttons["開始"]
        XCTAssertTrue(startFromPlan.waitForExistence(timeout: 5))
        startFromPlan.tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["開始訓練"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        app.buttons["結束訓練"].tap()
        let saveButton = app.buttons["完成並存檔"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        app.buttons["很硬"].firstMatch.tap()
        saveButton.tap()

        // 排課已 done → 訓練首頁不再有今日排課
        XCTAssertTrue(app.staticTexts["今天沒有排課"].waitForExistence(timeout: 5))

        // 歷史：刪除該場（含確認）
        app.buttons["歷史"].tap()
        let dateRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '個動作'")).firstMatch
        XCTAssertTrue(dateRow.waitForExistence(timeout: 5))
        dateRow.tap()
        XCTAssertTrue(app.buttons["workoutDetail.delete"].waitForExistence(timeout: 5))
        app.buttons["workoutDetail.delete"].tap()
        let confirm = app.alerts.buttons["刪除"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // 排課還原為未完成 → 訓練首頁又出現「開始」
        app.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 5))
    }
}
