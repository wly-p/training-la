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
        let completeBand = app.buttons["activeWorkout.completeBand.primary"]
        XCTAssertTrue(completeBand.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["activeWorkout.completeBandTitle"].exists)
        XCTAssertTrue(app.buttons["activeWorkout.completeBand.addSet"].exists)
        // 組表沒被蓋住：最後一組的 ↩ 還在原位，誤按的復原成本是零。
        XCTAssertTrue(app.buttons["activeWorkout.undoSet"].exists)
        // 16b 只有兩顆。加練是訓練層級的，只在課表做完（16e）才出現。
        XCTAssertFalse(app.buttons["activeWorkout.completeBand.addExtra"].exists)

        // 加一組 → 回到輸入態 → 再完成一組 → 應該再回到完成區。
        // 回歸：原本按過一次加一組之後就再也不問，會一路接著做到第 7、8 組。
        app.buttons["activeWorkout.completeBand.addSet"].tap()
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        app.waitForCurrentSet(4)
        complete.tap()
        XCTAssertTrue(
            app.staticTexts["activeWorkout.completeBandTitle"].waitForExistence(timeout: 5),
            "加一組之後每多做一組都要再回到完成區"
        )

        // 點「下一個 · 測試深蹲 →」→ 進到測試深蹲（動作名是測試自己輸入的資料）
        completeBand.tap()
        XCTAssertTrue(app.navigationBars["測試深蹲"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["activeWorkout.completeBandTitle"].exists)
    }

    /// 課表全部做完（16e）：三顆按鈕都在，且「加練」選完動作要真的切過去。
    @MainActor
    func testPlanDoneBandHasAddSetAndAddExtraWorks() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        app.addExercise(named: "測試深蹲")   // 只入庫，不排進課表——留給「加練」挑
        // 課表只有一個動作，做滿就是整場做完
        app.createBlankPlan(named: "推日", exercises: ["測試臥推"])
        app.startTodaysPlan()

        let complete = app.buttons["activeWorkout.completeSet"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        app.waitForCurrentSet(2)
        complete.tap()
        app.waitForCurrentSet(3)
        complete.tap()

        // 16e：加一組 ｜ 加練 ｜ 結束訓練。三顆都要在——最後一個動作同時是
        // 「再一組」與「加練」的最後機會，少了哪個都是死路。
        XCTAssertTrue(app.buttons["activeWorkout.completeBand.primary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["activeWorkout.completeBand.addSet"].exists)
        XCTAssertTrue(app.buttons["activeWorkout.completeBand.addExtra"].exists)

        // 加練 → 選一個課表外的動作 → 完成區要收掉並切到該動作
        app.buttons["activeWorkout.completeBand.addExtra"].tap()
        app.pickExercise("測試深蹲")
        XCTAssertTrue(app.navigationBars["測試深蹲"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts["activeWorkout.completeBandTitle"].exists,
            "加練選完動作，完成區應該收掉並回到輸入態"
        )
        XCTAssertTrue(app.buttons["activeWorkout.completeSet"].waitForExistence(timeout: 5))
    }
}
