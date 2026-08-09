import XCTest

final class RestTimerUITests: XCTestCase {
    @MainActor
    func testRestCountdownPopsUpAfterCompletingSet() throws {
        let app = XCUIApplication()
        app.launchArguments = uitestLaunchArguments()
        app.launch()

        // 動作庫建一個動作
        app.buttons["動作庫"].tap()
        app.buttons["library.add"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("測試臥推")
        app.buttons["儲存"].tap()
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        app.clearExerciseListSearch()

        // 課表：新增排課，休息設 2 秒
        app.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("休息測試")
        app.buttons["加入動作"].tap()
        app.pickExercise("測試臥推")
        app.buttons["加入 1 個動作"].tap()

        // 新版：點動作列開編輯 sheet，把休息從預設 0（不設）加到 15 秒（stepper 15 秒一階，按 ＋ 一次）。
        app.staticTexts["測試臥推"].firstMatch.tap()
        let restStepper = app.steppers["draftRestStepper"]
        XCTAssertTrue(restStepper.waitForExistence(timeout: 5))
        restStepper.buttons.element(boundBy: 1).tap()
        app.buttons["完成"].tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["休息測試"].waitForExistence(timeout: 5))

        // 照課表訓練，完成一組
        app.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["開始"].waitForExistence(timeout: 5))
        app.buttons["開始"].tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["開始訓練"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        // 休息倒數條出現
        XCTAssertTrue(app.staticTexts["休息中"].waitForExistence(timeout: 3))

        // 時間到 → 彈窗（休息 15 秒，放寬 timeout）
        let popup = app.staticTexts["休息結束"]
        XCTAssertTrue(popup.waitForExistence(timeout: 20))
        app.buttons["開始下一組"].tap()

        // 彈窗關閉、可繼續記下一組
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["休息結束"].exists)
    }
}
