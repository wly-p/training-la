import XCTest

final class ScheduleFlowUITests: XCTestCase {
    @MainActor
    func testScheduleThenTrainFromPlan() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
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

        // 2. 課表新增一個循環排課（不指定日期）
        app.tabBars.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("推日")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 3. 訓練首頁：出現今日排課卡 + 照課表開始
        app.tabBars.buttons["訓練"].tap()
        let planCard = app.staticTexts["推日"]
        XCTAssertTrue(planCard.waitForExistence(timeout: 5))
        app.buttons["照課表開始"].tap()

        // 4. 記錄畫面：自動選到臥推、顯示目標
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        let targetLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '目標'")).firstMatch
        XCTAssertTrue(targetLabel.waitForExistence(timeout: 5))

        // 5. 記一組並結束
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))
        app.buttons["結束訓練"].tap()
        let saveButton = app.buttons["儲存並結束"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // 6. 歷史詳情顯示目標快照（證明照課表記錄有帶入 target）
        app.tabBars.buttons["歷史"].tap()
        app.cells.firstMatch.tap()
        let targetSnapshot = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '目標'")).firstMatch
        XCTAssertTrue(targetSnapshot.waitForExistence(timeout: 5))
    }
}
