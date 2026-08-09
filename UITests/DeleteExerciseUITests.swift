import XCTest

final class DeleteExerciseUITests: XCTestCase {
    @MainActor
    func testDeletingReferencedExerciseIsBlocked() throws {
        let app = XCUIApplication()
        app.launchArguments = uitestLaunchArguments()
        app.launch()

        // 建動作
        app.buttons["動作庫"].tap()
        app.buttons["library.add"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("測試臥推")
        app.buttons["儲存"].tap()
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        app.clearExerciseListSearch()

        // 把它排進課表（產生引用）
        app.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("推日")
        app.buttons["加入動作"].tap()
        app.pickExercise("測試臥推")
        app.buttons["加入 1 個動作"].tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 回動作庫嘗試刪除 → 被擋（長按 context menu → 刪除）
        app.buttons["動作庫"].tap()
        let row = app.staticTexts["測試臥推"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.0)
        let deleteButton = app.buttons["刪除"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["此動作已被課表或訓練紀錄使用，無法刪除"].waitForExistence(timeout: 5))
        app.buttons["好"].tap()

        // 動作還在
        XCTAssertTrue(app.staticTexts["測試臥推"].exists)
    }
}
