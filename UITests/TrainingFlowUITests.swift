import XCTest

final class TrainingFlowUITests: XCTestCase {
    @MainActor
    func testRecordWorkoutHappyPath() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"] // 乾淨的 in-memory store
        app.launch()

        // 1. 先在動作庫建一個動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("深蹲")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["深蹲"].waitForExistence(timeout: 5))

        // 2. 開始訓練 → 自動彈出選動作（保險起見沒彈出就手動點「加入動作」）
        app.tabBars.buttons["訓練"].tap()
        app.buttons["開始訓練"].tap()
        let pickerTitle = app.navigationBars["選擇動作"]
        if !pickerTitle.waitForExistence(timeout: 3) {
            app.buttons["加入動作"].tap()
            XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5))
        }
        let pickerRow = app.staticTexts["深蹲"].firstMatch
        XCTAssertTrue(pickerRow.waitForExistence(timeout: 5))
        pickerRow.tap()

        // 3. 記兩組（預設 20kg × 8）
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第2組"].waitForExistence(timeout: 5))

        // 4. 結束 → 選感受 → 儲存
        app.buttons["結束訓練"].tap()
        let saveButton = app.buttons["儲存並結束"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        app.buttons["💪"].firstMatch.tap()
        saveButton.tap()

        // 5. 回到訓練首頁：場次已結束，重新顯示「開始訓練」
        XCTAssertTrue(app.buttons["開始訓練"].waitForExistence(timeout: 5))
    }
}
