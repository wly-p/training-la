import XCTest

/// #2 迴歸：照課表訓練完成後刪除該場歷史紀錄 → 對應排課應還原為未完成
/// （訓練首頁重新出現「開始」）。
final class DeleteHistoryRevertsPlanUITests: XCTestCase {
    @MainActor
    func testDeleteHistoryRevertsPlanStatus() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        // 課表：新增今天的排課「推日」含測試臥推
        app.createBlankPlan(named: "推日", exercises: ["測試臥推"])

        // 訓練：開始 → 完成一組 → 結束存檔
        app.startTodaysPlan()
        let completeButton = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        app.waitForCurrentSet(2)
        app.buttons["activeWorkout.finish"].tap()
        let saveButton = app.buttons["finishSheet.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        app.buttons["finishSheet.feeling.5"].firstMatch.tap()
        saveButton.tap()

        // 排課已 done → 訓練首頁不再有今日排課
        XCTAssertTrue(app.staticTexts["training.noPlanCard"].waitForExistence(timeout: 5))

        // 歷史：刪除該場（含確認）
        app.buttons["tabBar.item.history"].tap()
        let dateRow = app.buttons["history.workoutRow"].firstMatch
        XCTAssertTrue(dateRow.waitForExistence(timeout: 5))
        dateRow.tap()
        XCTAssertTrue(app.buttons["workoutDetail.delete"].waitForExistence(timeout: 5))
        app.buttons["workoutDetail.delete"].tap()
        let confirm = app.alerts.buttons["workoutDetail.deleteConfirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // 排課還原為未完成 → 訓練首頁又出現今天的排課
        app.buttons["tabBar.item.training"].tap()
        XCTAssertTrue(app.buttons["training.startCard"].waitForExistence(timeout: 5))
    }
}
