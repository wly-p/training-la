import XCTest

/// bug①：組間休息倒數切到其他 App 會暫停。
/// 倒數改以「結束時間 + 切回前景重算」為準，App 進背景不會暫停。
/// 這個測試在休息中把 App 切到背景、待休息時間過完再切回，驗證休息已結束（沒有被暫停）。
final class BackgroundRestUITests: XCTestCase {
    @MainActor
    func testRestKeepsCountingWhileAppInBackground() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        // 課表：把休息從預設 0（不設）加到 15 秒（stepper 15 秒一階）
        app.createBlankPlan(named: "背景測試", exercises: ["測試臥推"]) { app in
            app.raiseRest(onPlanExercise: "測試臥推")
        }

        // 照課表訓練，完成一組 → 進入休息
        app.startTodaysPlan()
        let completeButton = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["activeWorkout.resting"].waitForExistence(timeout: 3))

        // 切到背景，待超過休息時間（15 秒）再切回
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 17)
        app.activate()

        // 切回前景後：休息已結束（沒有被暫停），而且**直接回到組表輸入態**。
        // 背景到點時系統通知已經提醒過一次，這裡不該再彈一次「休息結束」要人多按一下
        // （bug：組間休息提醒重複）。
        XCTAssertTrue(
            app.buttons["activeWorkout.completeSet"].waitForExistence(timeout: 5),
            "背景期間倒數應持續進行，切回時休息應已結束並回到組表"
        )
        XCTAssertFalse(
            app.staticTexts["activeWorkout.resting"].exists,
            "休息已經到點，不該還停在休息畫面"
        )
        XCTAssertFalse(
            app.alerts.element.exists,
            "背景通知已經提醒過一次，回前景不該再彈一次彈窗"
        )
    }
}
