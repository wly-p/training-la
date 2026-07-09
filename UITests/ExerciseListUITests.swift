import XCTest

final class ExerciseListUITests: XCTestCase {
    @MainActor
    func testAddExerciseShowsUpInList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"] // 乾淨的 in-memory store
        app.launch()

        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()

        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap()

        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // swipe 刪除
        let row = app.cells.containing(.staticText, identifier: "臥推").firstMatch
        row.swipeLeft()
        let deleteButton = app.buttons["刪除"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["還沒有動作"].waitForExistence(timeout: 5))
    }
}
