import XCTest

final class ExerciseListUITests: XCTestCase {
    @MainActor
    func testAddExerciseShowsUpInList() throws {
        let app = XCUIApplication()
        app.launch()

        // 名稱帶時間戳，避免依賴模擬器裡既有的資料
        let name = "臥推\(Int(Date().timeIntervalSince1970) % 100_000)"

        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()

        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        app.buttons["儲存"].tap()

        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        // 清掉這筆，讓測試可重複跑
        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        row.swipeLeft()
        let deleteButton = app.buttons["刪除"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let gone = app.staticTexts[name].waitForNonExistence(timeout: 5)
        XCTAssertTrue(gone)
    }
}
