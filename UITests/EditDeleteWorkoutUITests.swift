import XCTest

/// 編輯 / 刪除訓練紀錄：從歷史詳情頁改一組狀態、刪整場，驗證歷史一致更新。
final class EditDeleteWorkoutUITests: XCTestCase {
    @MainActor
    func testEditSetThenDeleteWorkout() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試深蹲")
        app.recordFreeWorkout(with: "測試深蹲", sets: 2)

        // 進歷史「按日期」→ 點該場
        app.buttons["tabBar.item.history"].tap()
        let dateRow = app.buttons["history.workoutRow"].firstMatch
        XCTAssertTrue(dateRow.waitForExistence(timeout: 5))
        dateRow.tap()
        XCTAssertTrue(app.staticTexts["測試深蹲"].waitForExistence(timeout: 5))

        // 編輯：把第一組狀態改「跳過」→ 完成
        app.buttons["workoutDetail.edit"].tap()
        let skipSegment = app.buttons["workoutDetail.statusSegment.skipped"].firstMatch
        XCTAssertTrue(skipSegment.waitForExistence(timeout: 5))
        skipSegment.tap()
        app.buttons["workoutDetail.saveEdit"].tap()

        // 顯示模式下該組出現「跳過」標籤 → 編輯已落地
        XCTAssertTrue(app.staticTexts["workoutDetail.setStatus.skipped"].waitForExistence(timeout: 5))

        // 刪除整場（含確認）
        app.buttons["workoutDetail.delete"].tap()
        let confirm = app.alerts.buttons["workoutDetail.deleteConfirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // 回到歷史清單：唯一一場已刪 → 空狀態
        XCTAssertTrue(app.staticTexts["history.empty"].waitForExistence(timeout: 5))
    }
}
