import XCTest

final class TrainingFlowUITests: XCTestCase {
    @MainActor
    func testRecordWorkoutHappyPath() throws {
        let app = XCUIApplication()
        launchForUITest(app) // 乾淨的 in-memory store

        // 1. 先在動作庫建一個動作
        app.addExercise(named: "測試深蹲")

        // 2. 開始自由訓練 → 選動作
        app.startFreeTraining(with: "測試深蹲")

        // 3. 記兩組（預設 20kg × 8）
        let completeButton = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        app.waitForCurrentSet(2)
        XCTAssertEqual(app.completedSetCount, 1)
        completeButton.tap()
        app.waitForCurrentSet(3)
        XCTAssertEqual(app.completedSetCount, 2)

        // 4. 結束 → 選感受（「很硬」＝ 5）→ 儲存
        app.buttons["activeWorkout.finish"].tap()
        let saveButton = app.buttons["finishSheet.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        app.buttons["finishSheet.feeling.5"].firstMatch.tap()
        saveButton.tap()

        // 5. 回到訓練首頁：場次已結束，重新顯示可以再開一場
        XCTAssertTrue(app.buttons["training.startFree"].waitForExistence(timeout: 5))

        // 6. 歷史頁「按日期」看得到這場，點進去看得到動作
        app.buttons["tabBar.item.history"].tap()
        let dateRow = app.buttons["history.workoutRow"].firstMatch
        XCTAssertTrue(dateRow.waitForExistence(timeout: 5))
        dateRow.tap()
        XCTAssertTrue(app.staticTexts["測試深蹲"].waitForExistence(timeout: 5))

        // 7. 切「按動作」，該動作有紀錄（清單列出動作名，點進去才是單一動作歷史頁）
        app.navigationBars.buttons.firstMatch.tap() // 返回
        app.buttons["history.segment.byExercise"].tap()
        XCTAssertTrue(app.staticTexts["測試深蹲"].waitForExistence(timeout: 5))
    }
}
