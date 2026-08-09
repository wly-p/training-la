import XCTest

/// bug①：組間休息倒數切到其他 App 會暫停。
/// 倒數改以「結束時間 + 切回前景重算」為準，App 進背景不會暫停。
/// 這個測試在休息中把 App 切到背景、待休息時間過完再切回，驗證休息已結束（沒有被暫停）。
final class BackgroundRestUITests: XCTestCase {
    @MainActor
    func testRestKeepsCountingWhileAppInBackground() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
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

        // 課表：休息設 5 秒
        app.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        app.buttons["空白建立"].tap()  // 「+」選單 → 空白建立
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("背景測試")
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
        XCTAssertTrue(app.staticTexts["背景測試"].waitForExistence(timeout: 5))

        // 照課表訓練，完成一組 → 進入休息
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
        XCTAssertTrue(app.staticTexts["休息中"].waitForExistence(timeout: 3))

        // 切到背景，待超過休息時間（15 秒）再切回
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 17)
        app.activate()

        // 切回前景後：休息已結束（沒有被暫停），而且**直接回到組表輸入態**。
        // 背景到點時系統通知已經提醒過一次，這裡不該再彈一次「休息結束」要人多按一下
        // （bug：組間休息提醒重複）。
        XCTAssertTrue(
            app.buttons["完成此組"].waitForExistence(timeout: 5),
            "背景期間倒數應持續進行，切回時休息應已結束並回到組表"
        )
        XCTAssertFalse(
            app.staticTexts["休息中"].exists,
            "休息已經到點，不該還停在休息畫面"
        )
        XCTAssertFalse(
            app.staticTexts["休息結束"].exists,
            "背景通知已經提醒過一次，回前景不該再彈一次彈窗"
        )
    }
}
