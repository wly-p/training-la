import XCTest

/// 編輯 / 刪除訓練紀錄：從歷史詳情頁改一組狀態、刪整場，驗證歷史一致更新。
final class EditDeleteWorkoutUITests: XCTestCase {
    @MainActor
    func testEditSetThenDeleteWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        recordOneWorkout(app, exerciseName: "深蹲")

        // 進歷史「按日期」→ 點該場
        app.tabBars.buttons["歷史"].tap()
        let dateRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '個動作'")).firstMatch
        XCTAssertTrue(dateRow.waitForExistence(timeout: 5))
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["深蹲"].waitForExistence(timeout: 5))

        // 編輯：把第一組狀態改「跳過」→ 完成
        app.buttons["workoutDetail.edit"].tap()
        let skipSegment = app.buttons["跳過"].firstMatch
        XCTAssertTrue(skipSegment.waitForExistence(timeout: 5))
        skipSegment.tap()
        app.buttons["workoutDetail.saveEdit"].tap()

        // 顯示模式下該組出現「跳過」標籤 → 編輯已落地
        XCTAssertTrue(app.staticTexts["跳過"].waitForExistence(timeout: 5))

        // 刪除整場（含確認）
        app.buttons["workoutDetail.delete"].tap()
        let confirm = app.buttons["刪除"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // 回到歷史清單：唯一一場已刪 → 空狀態
        XCTAssertTrue(app.staticTexts["還沒有訓練紀錄"].waitForExistence(timeout: 5))
    }

    /// 建一個動作、記兩組、結束存檔（複用 happy path 的步驟）。
    @MainActor
    private func recordOneWorkout(_ app: XCUIApplication, exerciseName: String) {
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(exerciseName)
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5))

        app.tabBars.buttons["訓練"].tap()
        app.buttons["開始訓練"].tap()
        let pickerTitle = app.navigationBars["選擇動作"]
        if !pickerTitle.waitForExistence(timeout: 3) {
            app.buttons["加入動作"].tap()
            XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5))
        }
        let pickerRow = app.staticTexts[exerciseName].firstMatch
        XCTAssertTrue(pickerRow.waitForExistence(timeout: 5))
        pickerRow.tap()

        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第2組"].waitForExistence(timeout: 5))

        app.buttons["結束訓練"].tap()
        let saveButton = app.buttons["儲存並結束"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        app.buttons["💪"].firstMatch.tap()
        saveButton.tap()
        XCTAssertTrue(app.buttons["開始訓練"].waitForExistence(timeout: 5))
    }
}
