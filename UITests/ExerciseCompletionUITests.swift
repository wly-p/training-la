import XCTest

final class ExerciseCompletionUITests: XCTestCase {
    @MainActor
    func testCompletionCardAppearsAndAdvances() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        app.addExercise(named: "測試深蹲")
        // 課表：測試臥推 + 測試深蹲（各預設 3 組、不設休息，避免倒數拖慢測試）
        app.createBlankPlan(named: "推日", exercises: ["測試臥推", "測試深蹲"])
        app.startTodaysPlan()

        // 完成測試臥推 3 組
        let complete = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        app.waitForCurrentSet(2)
        complete.tap()
        app.waitForCurrentSet(3)
        complete.tap()

        // 第 3 組後 → 就地把輸入色帶換成完成區（16b），**不開彈窗**
        let completeBand = app.buttons["activeWorkout.completeBandPrimary"]
        XCTAssertTrue(completeBand.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["activeWorkout.completeBandTitle"].exists)
        XCTAssertTrue(app.buttons["activeWorkout.completeBandSecondary"].exists)
        // 組表沒被蓋住：最後一組的 ↩ 還在原位，誤按的復原成本是零。
        XCTAssertTrue(app.buttons["activeWorkout.undoSet"].exists)

        // 點「下一個 · 測試深蹲 →」→ 進到測試深蹲（動作名是測試自己輸入的資料）
        completeBand.tap()
        XCTAssertTrue(app.navigationBars["測試深蹲"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["activeWorkout.completeBandTitle"].exists)
    }
}
