import XCTest

final class DeleteExerciseUITests: XCTestCase {
    @MainActor
    func testDeletingReferencedExerciseIsBlocked() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 建動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 把它排進課表（產生引用）
        app.tabBars.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("推日")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 回動作庫嘗試刪除 → 被擋
        app.tabBars.buttons["動作庫"].tap()
        let row = app.cells.containing(.staticText, identifier: "臥推").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["刪除"].tap()

        XCTAssertTrue(app.staticTexts["此動作已被課表或訓練紀錄使用，無法刪除"].waitForExistence(timeout: 5))
        app.buttons["好"].tap()

        // 動作還在
        XCTAssertTrue(app.staticTexts["臥推"].exists)
    }
}
