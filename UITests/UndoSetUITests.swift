import XCTest

/// bug②：訓練中誤按「完成此組」無法取消。
/// 完成一組後，那一組的記錄列右側會出現復原鍵，點了應把剛記的那組移除、回到未記錄狀態。
final class UndoSetUITests: XCTestCase {
    @MainActor
    func testUndoRemovesJustRecordedSet() throws {
        let app = XCUIApplication()
        launchForUITest(app) // 乾淨的 in-memory store

        app.addExercise(named: "測試臥推")
        app.startFreeTraining(with: "測試臥推")

        // 完成一組 → 前進到「第2組」，該組記錄列出現復原鍵
        let completeButton = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        app.waitForCurrentSet(2)
        let undo = app.buttons["activeWorkout.undoSet"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))

        // 復原 → 回到未記錄狀態（退回第1組、復原按鈕消失）
        undo.tap()
        app.waitForCurrentSet(1)
        XCTAssertEqual(app.completedSetCount, 0, "復原後不應還留著剛記錄的那一組")
        XCTAssertFalse(app.buttons["activeWorkout.undoSet"].exists, "沒有可復原的組時，復原按鈕應消失")
    }

    /// 誤按的是「該動作最後一組」時會進完成狀態。完成區就地取代輸入色帶、不蓋住組表，
    /// 所以組表上那顆 ↩ 照樣點得到：點了應收掉完成區並把那組移除。
    @MainActor
    func testUndoFromExerciseCompleteCard() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        app.addExercise(named: "測試深蹲")
        // 課表：測試臥推 + 測試深蹲（各預設 3 組）
        app.createBlankPlan(named: "推日", exercises: ["測試臥推", "測試深蹲"])
        app.startTodaysPlan()

        // 測試臥推 3 組做滿 → 完成區（第 3 組就是「誤按」的那組）
        let complete = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        app.waitForCurrentSet(2)
        complete.tap()
        app.waitForCurrentSet(3)
        complete.tap()
        XCTAssertTrue(app.buttons["activeWorkout.completeBandPrimary"].waitForExistence(timeout: 5))

        // 完成區不蓋住組表，所以復原就用組表上原本那顆 ↩（不再另外開一顆卡片專用的）。
        let undo = app.buttons["activeWorkout.undoSet"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertFalse(
            app.buttons["activeWorkout.completeBandPrimary"].waitForExistence(timeout: 2),
            "復原後完成區應收掉、換回輸入色帶"
        )
        app.waitForCurrentSet(3)
        // 動作名是測試自己輸入的資料，與介面語言無關 → 用文字定位是對的。
        XCTAssertTrue(app.navigationBars["測試臥推"].exists, "應留在測試臥推，不該被帶去下一個動作")
    }
}
