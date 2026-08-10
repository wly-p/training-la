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

        // 時間到 → 彈窗（休息 15 秒，放寬 timeout）。
        // 查詢限定在 alert 裡並且不要事先快取：identifier 掛在 alert 的 Button 上時 SwiftUI 會
        // 同時印在外層與內層兩個巢狀 Button，而彈窗出現的瞬間還會重繪一次，
        // 快取住的 element 可能點到已經失效的那一個。
        XCTAssertTrue(
            app.alerts.buttons["activeWorkout.restEnded.next"].firstMatch.waitForExistence(timeout: 20)
        )
        app.alerts.buttons["activeWorkout.restEnded.next"].firstMatch.tap()

        // 彈窗關閉、可繼續記下一組
        XCTAssertTrue(app.buttons["activeWorkout.completeSet"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.element.exists)
    }
}
