import XCTest

final class ExerciseCompletionUITests: XCTestCase {
    @MainActor
    func testCompletionCardAppearsAndAdvances() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        addExercise(app, name: "臥推")
        addExercise(app, name: "深蹲")

        // 課表：臥推 + 深蹲（各預設 3 組、不設休息，避免倒數拖慢測試）
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

        // 照課表開始
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["照課表開始"].waitForExistence(timeout: 5))
        app.buttons["照課表開始"].tap()

        // 完成臥推 3 組
        let complete = app.buttons["完成此組"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["第2組"].waitForExistence(timeout: 5))
        complete.tap()

        // 第 3 組後 → 完成卡片
        XCTAssertTrue(app.staticTexts["臥推 完成"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["接下來：深蹲"].exists)
        XCTAssertTrue(app.buttons["再做一組"].exists) // 繼續做的小按鈕

        // 點「下一個動作」→ 進到深蹲
        app.buttons["下一個動作"].tap()
        XCTAssertTrue(app.navigationBars["深蹲"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["臥推 完成"].exists)
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
