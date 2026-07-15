import XCTest

/// bug②：訓練中誤按「完成此組」無法取消。
/// 完成一組後，記錄區 header 會出現「復原上一組」，點了應把剛記的那組移除、回到未記錄狀態。
final class UndoSetUITests: XCTestCase {
    @MainActor
    func testUndoRemovesJustRecordedSet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"] // 乾淨的 in-memory store
        app.launch()

        // 1. 動作庫建一個動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 2. 開始訓練 → 選動作
        app.tabBars.buttons["訓練"].tap()
        app.buttons["開始訓練"].tap()
        let pickerTitle = app.navigationBars["選擇動作"]
        if !pickerTitle.waitForExistence(timeout: 3) {
            app.buttons["加入動作"].tap()
            XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5))
        }
        let pickerRow = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pickerRow.waitForExistence(timeout: 5))
        pickerRow.tap()

        // 3. 完成一組 → header 前進到「第2組」，出現「復原上一組」
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第2組"].waitForExistence(timeout: 5))
        let undo = app.buttons["復原上一組"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))

        // 4. 復原 → 回到未記錄狀態（「第2組」消失、復原按鈕消失）
        undo.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts["第2組"].waitForExistence(timeout: 2),
            "復原後不應還留著剛記錄的那一組"
        )
        XCTAssertFalse(app.buttons["復原上一組"].exists, "沒有可復原的組時，復原按鈕應消失")
    }
}
