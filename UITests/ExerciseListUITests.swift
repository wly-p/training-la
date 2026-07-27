import XCTest

final class ExerciseListUITests: XCTestCase {
    @MainActor
    func testAddExerciseShowsUpInList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"] // 乾淨的 in-memory store
        app.launch()

        app.buttons["動作庫"].tap()
        app.buttons["libraryAddButton"].tap()

        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap() // 器材用預設（槓鈴）

        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))
        // 列表列顯示器材（預設槓鈴）→ 證明 equipment 有存進去並顯示
        XCTAssertTrue(app.staticTexts["槓鈴"].waitForExistence(timeout: 5))

        // 長按列叫出 context menu → 刪除（DesignSystem 容器非原生 List，無 swipe）
        app.staticTexts["臥推"].press(forDuration: 1.0)
        let deleteButton = app.buttons["刪除"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["還沒有動作"].waitForExistence(timeout: 5))
    }
}
