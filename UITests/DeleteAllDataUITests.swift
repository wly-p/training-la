import XCTest

final class DeleteAllDataUITests: XCTestCase {
    @MainActor
    func testDeleteAllDataClearsExercisesAndReturnsToFreshState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 先建一筆資料
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 設定 → 刪除所有資料 → 二次確認
        app.tabBars.buttons["設定"].tap()
        let deleteButton = app.buttons["deleteAllDataButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // confirmationDialog 的按鈕在階層裡可能有雙份表示，用 firstMatch 消歧義。
        let confirm = app.buttons["confirmDeleteAllDataButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // 畫面重建後，回動作庫應該已清空（剛建的「臥推」不見了）
        let exercisesTab = app.tabBars.buttons["動作庫"]
        XCTAssertTrue(exercisesTab.waitForExistence(timeout: 5))
        exercisesTab.tap()
        XCTAssertFalse(
            app.staticTexts["臥推"].waitForExistence(timeout: 3),
            "刪除所有資料後，動作庫應回到空狀態"
        )
    }
}
