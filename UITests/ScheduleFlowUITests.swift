import XCTest

final class ScheduleFlowUITests: XCTestCase {
    @MainActor
    func testScheduleThenTrainFromPlan() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        addExercise(app, name: "臥推")
        addExercise(app, name: "深蹲")

        // 課表：新增一個含兩個動作、當日（預設今天）的排課
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

        // 訓練首頁：出現今日排課卡 + 照課表開始
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["照課表開始"].tap()

        // 記錄畫面：自動選到第一個課表動作（臥推）並顯示目標
        XCTAssertTrue(app.navigationBars["臥推"].waitForExistence(timeout: 5))
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '目標'")).firstMatch.exists)

        // 完成臥推一組，然後「下一個動作」應直接帶到深蹲（不是打開全清單）
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        let nextButton = app.buttons["下一個動作：深蹲"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        // 現在當前動作是深蹲
        XCTAssertTrue(app.navigationBars["深蹲"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))

        // 完成深蹲一組 → 課表兩個動作都做過 → 顯示做完提示
        app.buttons["完成此組"].tap()
        XCTAssertTrue(app.staticTexts["課表動作都做完了，可結束或加練"].waitForExistence(timeout: 5))

        // 結束
        app.buttons["結束訓練"].tap()
        let saveButton = app.buttons["儲存並結束"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // 歷史詳情有兩個動作區塊 + 目標快照
        app.tabBars.buttons["歷史"].tap()
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["深蹲"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '目標'")).firstMatch.exists)
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
