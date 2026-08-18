import XCTest

final class DeleteExerciseUITests: XCTestCase {
    @MainActor
    func testDeletingReferencedExerciseIsBlocked() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        // 建動作
        app.buttons["tabBar.item.exercises"].tap()
        app.buttons["library.add"].tap()
        let nameField = app.textFields["editScaffold.title"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("測試臥推")
        app.buttons["editScaffold.save"].tap()
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        app.clearExerciseListSearch()

        // 把它排進課表（產生引用）
        app.buttons["tabBar.item.plan"].tap()
        app.buttons["plan.new"].tap()
        app.buttons["plan.addBlank"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["editScaffold.title"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("推日")
        app.buttons["planForm.addExercise"].tap()
        app.pickExercise("測試臥推")
        app.buttons["picker.confirm"].tap()
        app.buttons["editScaffold.save"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 回動作庫嘗試刪除 → 被擋（長按 context menu → 刪除）
        app.buttons["tabBar.item.exercises"].tap()
        let row = app.staticTexts["測試臥推"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.0)
        let deleteButton = app.buttons["exerciseList.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // 擋下來的理由（「已被課表或訓練紀錄使用」）文字會跟著語言換，只驗有跳錯誤 alert。
        // `.firstMatch` 不能省：identifier 掛在 alert 的 Button 上時，SwiftUI 會把它同時
        // 印在外層與內層兩個巢狀 Button 上，不指定就會因為「命中兩個」而點不下去。
        let ok = app.alerts.buttons["exerciseList.error.ok"].firstMatch
        XCTAssertTrue(ok.waitForExistence(timeout: 5), "刪除被引用的動作應該跳錯誤提示")
        ok.tap()

        // 動作還在
        XCTAssertTrue(app.staticTexts["測試臥推"].exists)
    }
}
