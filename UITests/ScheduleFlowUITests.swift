import XCTest

/// 排課 → 訓練 → 歷史的完整旅程。
///
/// 這是 identifier 化的第一條旅程（見 `ARCHITECTURE.md` 的命名規範）。測試主體裡沒有任何
/// 介面文字，只有 identifier 與「測試自己輸入的資料」（動作名、排課名）——後者是測試自己打進去的
/// 字串，本來就跟介面語言無關。
///
/// 原本這裡寫了中英兩支 func 手動各跑一次。現在整套測試都會跑兩輪（`make test-uitest`），
/// 這條旅程自然中英各跑一次，那份重複就收掉了。
final class ScheduleFlowUITests: XCTestCase {
    @MainActor
    func testScheduleThenTrainFromPlan() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        let benchPress = "測試臥推"
        let squat = "測試深蹲"
        let planName = "測試推日"

        app.addExercise(named: benchPress)
        app.addExercise(named: squat)

        // 課表：新增一個含兩個動作、當日（預設今天）的排課
        app.buttons["tabBar.item.plan"].tap()
        app.buttons["plan.new"].tap()
        app.buttons["plan.addBlank"].tap()
        let nameField = app.textFields["editScaffold.title"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(planName)
        app.addExerciseToPlan(named: benchPress)
        app.addExerciseToPlan(named: squat)
        app.buttons["editScaffold.save"].tap()
        XCTAssertTrue(app.staticTexts[planName].waitForExistence(timeout: 5))

        // 訓練首頁：出現今日排課卡 + 開始
        app.buttons["tabBar.item.training"].tap()
        XCTAssertTrue(app.staticTexts[planName].waitForExistence(timeout: 5))
        app.buttons["training.startCard"].tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["trainingPreview.start"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()

        // 記錄畫面：自動選到第一個課表動作並顯示組表
        XCTAssertTrue(app.navigationBars[benchPress].waitForExistence(timeout: 5))
        let completeButton = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["activeWorkout.targetColumn"].firstMatch.exists)
        // 下一組預覽（第一個動作還有下一組）
        XCTAssertTrue(app.staticTexts["activeWorkout.nextSetPreview"].firstMatch.waitForExistence(timeout: 5))

        // 完成一組 → 「本場動作」清單列出未做的第二個動作，點它直接跳過去（不是打開全動作庫）
        // 組表＋輸入色帶（11c 改版）變高了，「本場動作」要往下捲才會進 List 的可視/實例化範圍。
        completeButton.tap()
        app.waitForCompletedSet()
        let nextExercise = app.staticTexts[squat]
        if !nextExercise.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(nextExercise.waitForExistence(timeout: 5))
        nextExercise.tap()

        // 現在當前動作是第二個
        XCTAssertTrue(app.navigationBars[squat].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["activeWorkout.completeSet"].waitForExistence(timeout: 5))

        // 完成第二個動作一組 → 記錄下來
        app.buttons["activeWorkout.completeSet"].tap()
        app.waitForCompletedSet()

        // 結束
        app.buttons["activeWorkout.finish"].tap()
        let saveButton = app.buttons["finishSheet.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // 歷史詳情有兩個動作區塊 + 目標快照
        app.buttons["tabBar.item.history"].tap()
        let workoutRow = app.buttons["history.workoutRow"].firstMatch
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 5))
        workoutRow.tap()
        XCTAssertTrue(app.staticTexts[benchPress].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[squat].exists)
        XCTAssertTrue(app.staticTexts["workoutDetail.targetColumn"].firstMatch.exists)
    }

    // MARK: - Helpers

}
