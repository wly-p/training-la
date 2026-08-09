import XCTest

final class DeleteAllDataUITests: XCTestCase {
    @MainActor
    func testDeleteAllDataClearsExercisesAndReturnsToFreshState() throws {
        let app = XCUIApplication()
        app.launchArguments = uitestLaunchArguments()
        app.launch()

        // 先建一筆資料
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

        // 設定 → 刪除所有資料 → 二次確認
        app.buttons["設定"].tap()
        let deleteButton = app.buttons["deleteAllDataButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // 自訂確認對話框（TLConfirmationDialog）：確認鈕帶專屬 id，和設定列上同名的
        // 「刪除所有資料」按鈕消歧義。
        let confirm = app.buttons["eraseConfirmButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // 畫面重建後，回動作庫，使用者自建的那筆應該不見了。
        //
        // 不能再斷言「動作庫是空的」：內建動作清單（80 筆）常駐、不進 DB，所以刪光使用者資料
        // 之後它們仍然在。用搜尋把清單縮到只剩目標，才不會因為那筆剛好被擠到畫面外
        // 而誤判成「已刪除」。
        let exercisesTab = app.buttons["動作庫"]
        XCTAssertTrue(exercisesTab.waitForExistence(timeout: 5))
        exercisesTab.tap()
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(
            app.staticTexts["找不到符合的動作"].waitForExistence(timeout: 5),
            "刪除所有資料後，使用者自建的動作應該不見了"
        )
    }
}
