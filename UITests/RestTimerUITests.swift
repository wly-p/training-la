import XCTest

final class RestTimerUITests: XCTestCase {
    @MainActor
    func testRestCountdownPopsUpAfterCompletingSet() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        // 課表：把休息從預設 0（不設）加到 15 秒（stepper 15 秒一階）
        app.createBlankPlan(named: "休息測試", exercises: ["測試臥推"]) { app in
            app.raiseRest(onPlanExercise: "測試臥推")
        }

        // 照課表訓練，完成一組
        app.startTodaysPlan()
        let completeButton = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        // 休息倒數畫面出現
        XCTAssertTrue(app.staticTexts["activeWorkout.resting"].waitForExistence(timeout: 3))

        // 時間到 → 彈窗（休息 15 秒，所以 timeout 放寬）→ 收掉它
        app.dismissRestEndedAlert()

        // 彈窗關閉、可繼續記下一組
        XCTAssertTrue(app.buttons["activeWorkout.completeSet"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.element.exists)
    }
}
