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
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("推日")
        addExerciseToPlan(app, name: "臥推")
        addExerciseToPlan(app, name: "深蹲")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 訓練首頁：出現今日排課卡 + 開始
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["開始"].tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["開始訓練"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()

        // 記錄畫面：自動選到第一個課表動作（臥推）並顯示目標
        XCTAssertTrue(app.navigationBars["臥推"].waitForExistence(timeout: 5))
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '目標'")).firstMatch.exists)
        // 下一組預覽（臥推還有下一組）→ footer 顯示「下一組：…」
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '下一組'")).firstMatch.waitForExistence(timeout: 5))

        // 完成臥推一組 → 「本場動作」清單列出未做的深蹲，點它直接跳過去（不是打開全動作庫）
        // 組表＋輸入色帶（11c 改版）變高了，「本場動作」要往下捲才會進 List 的可視/實例化範圍。
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        let nextExercise = app.staticTexts["深蹲"]
        if !nextExercise.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(nextExercise.waitForExistence(timeout: 5))
        nextExercise.tap()

        // 現在當前動作是深蹲
        XCTAssertTrue(app.navigationBars["深蹲"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))

        // 完成深蹲一組 → 記錄下來（本場動作清單同時保有臥推、深蹲）
        app.buttons["完成此組"].tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))

        // 結束
        app.buttons["結束訓練"].tap()
        let saveButton = app.buttons["儲存並結束"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // 歷史詳情有兩個動作區塊 + 目標快照
        app.tabBars.buttons["歷史"].tap()
        let dateRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '個動作'")).firstMatch
        XCTAssertTrue(dateRow.waitForExistence(timeout: 5))
        dateRow.tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["深蹲"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '目標'")).firstMatch.exists)
    }

    // MARK: - Helpers

    @MainActor private func addExercise(_ app: XCUIApplication, name: String) {
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["libraryAddButton"].tap()
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
