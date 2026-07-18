import XCTest

/// bug②：訓練中誤按「完成此組」無法取消。
/// 完成一組後，那一組的記錄列右側會出現復原鍵，點了應把剛記的那組移除、回到未記錄狀態。
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

        // 3. 完成一組 → 前進到「第2組」，該組記錄列出現復原鍵
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

    /// 誤按的是「該動作最後一組」時會跳完成卡片，蓋住記錄區的復原鍵，
    /// 故卡片自己要有出口：點了應收掉卡片並把那組移除。
    @MainActor
    func testUndoFromExerciseCompleteCard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        addExercise(app, name: "臥推")
        addExercise(app, name: "深蹲")

        // 課表：臥推 + 深蹲（各預設 3 組）
        app.tabBars.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("推日")
        addExerciseToPlan(app, name: "臥推")
        addExerciseToPlan(app, name: "深蹲")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["照課表開始"].waitForExistence(timeout: 5))
        app.buttons["照課表開始"].tap()

        // 臥推 3 組做滿 → 完成卡片（第 3 組就是「誤按」的那組）
        let complete = app.buttons["完成此組"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第2組"].waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第3組"].waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["臥推 完成"].waitForExistence(timeout: 5))

        // 卡片上的復原 → 卡片收掉、退回第 3 組未記錄
        let undoFromCard = app.buttons["按錯了，復原上一組"]
        XCTAssertTrue(undoFromCard.waitForExistence(timeout: 5))
        undoFromCard.tap()
        XCTAssertFalse(
            app.staticTexts["臥推 完成"].waitForExistence(timeout: 2),
            "復原後完成卡片應收掉"
        )
        XCTAssertTrue(app.staticTexts["第3組"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["臥推"].exists, "應留在臥推，不該被帶去下一個動作")
    }

    // MARK: - Helpers

    @MainActor private func addExercise(_ app: XCUIApplication, name: String) {
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let field = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    @MainActor private func addExerciseToPlan(_ app: XCUIApplication, name: String) {
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts[name].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
    }
}
