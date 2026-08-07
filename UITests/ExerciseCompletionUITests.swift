import XCTest

final class ExerciseCompletionUITests: XCTestCase {
    @MainActor
    func testCompletionCardAppearsAndAdvances() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        addExercise(app, name: "測試臥推")
        addExercise(app, name: "測試深蹲")

        // 課表：測試臥推 + 測試深蹲（各預設 3 組、不設休息，避免倒數拖慢測試）
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

        // 開始
        app.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 5))
        app.buttons["開始"].tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["開始訓練"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()

        // 完成測試臥推 3 組
        let complete = app.buttons["完成此組"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第2組"].waitForExistence(timeout: 5))
        complete.tap()

        // 第 3 組後 → 完成卡片
        XCTAssertTrue(app.staticTexts["測試臥推 完成"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["接下來：測試深蹲"].exists)
        XCTAssertTrue(app.buttons["再做一組"].exists) // 繼續做的小按鈕

        // 點「下一個動作」→ 進到測試深蹲
        app.buttons["下一個動作"].tap()
        XCTAssertTrue(app.navigationBars["測試深蹲"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["測試臥推 完成"].exists)
    }

    // MARK: - Helpers

    @MainActor private func addExercise(_ app: XCUIApplication, name: String) {
        app.buttons["動作庫"].tap()
        app.buttons["library.add"].tap()
        let field = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["儲存"].tap()
        app.searchExerciseList(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.clearExerciseListSearch()
    }

    @MainActor private func addExerciseToPlan(_ app: XCUIApplication, name: String) {
        // 空白排課表單改用新版 PickerSheet（多選）：點名字選取 → 按「加入 1 個動作」確認。
        app.buttons["加入動作"].tap()
        app.pickExercise(name)
        app.buttons["加入 1 個動作"].tap()
    }
}
