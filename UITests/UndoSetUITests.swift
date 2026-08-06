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
        app.buttons["動作庫"].tap()
        app.buttons["libraryAddButton"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("測試臥推")
        app.buttons["儲存"].tap()
        app.searchExercises("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        app.clearExerciseSearch()

        // 2. 開始訓練 → 選動作
        app.buttons["訓練"].tap()
        app.buttons["自由訓練 · 邊練邊加動作"].tap()
        let pickerTitle = app.staticTexts["選擇動作"]
        if !pickerTitle.waitForExistence(timeout: 3) {
            app.buttons["加入動作"].tap()
            XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5))
        }
        app.pickExercise("測試臥推")

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

        addExercise(app, name: "測試臥推")
        addExercise(app, name: "測試深蹲")

        // 課表：測試臥推 + 測試深蹲（各預設 3 組）
        app.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("推日")
        addExerciseToPlan(app, name: "測試臥推")
        addExerciseToPlan(app, name: "測試深蹲")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        app.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 5))
        app.buttons["開始"].tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["開始訓練"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()

        // 測試臥推 3 組做滿 → 完成卡片（第 3 組就是「誤按」的那組）
        let complete = app.buttons["完成此組"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第2組"].waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第3組"].waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["測試臥推 完成"].waitForExistence(timeout: 5))

        // 卡片上的復原 → 卡片收掉、退回第 3 組未記錄
        let undoFromCard = app.buttons["按錯了，復原上一組"]
        XCTAssertTrue(undoFromCard.waitForExistence(timeout: 5))
        undoFromCard.tap()
        XCTAssertFalse(
            app.staticTexts["測試臥推 完成"].waitForExistence(timeout: 2),
            "復原後完成卡片應收掉"
        )
        XCTAssertTrue(app.staticTexts["第3組"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["測試臥推"].exists, "應留在測試臥推，不該被帶去下一個動作")
    }

    // MARK: - Helpers

    @MainActor private func addExercise(_ app: XCUIApplication, name: String) {
        app.buttons["動作庫"].tap()
        app.buttons["libraryAddButton"].tap()
        let field = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["儲存"].tap()
        app.searchExercises(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.clearExerciseSearch()
    }

    @MainActor private func addExerciseToPlan(_ app: XCUIApplication, name: String) {
        // 空白排課表單改用新版 PickerSheet（多選）：點名字選取 → 按「加入 1 個動作」確認。
        app.buttons["加入動作"].tap()
        app.pickExercise(name)
        app.buttons["加入 1 個動作"].tap()
    }
}
