import XCTest

/// 排課 → 訓練 → 歷史的完整旅程，**兩種語言各跑一次**。
///
/// 這是 identifier 化的第一條旅程（見 `ARCHITECTURE.md` 的命名規範）。測試主體裡沒有任何
/// 介面文字，只有 identifier 與「測試自己輸入的資料」（動作名、排課名）——後者是測試自己打進去的
/// 字串，本來就跟介面語言無關。
///
/// ⚠️ 英文版跑的組合是「**裝置語系繁中 ＋ App 語言英文**」。兩邊都設英文的話 `String(localized:)`
/// 也會回英文，反而把「不跟著 App 語言切」這個 bug 藏起來——這個盲點讓同一個根因來要帳三次。
final class ScheduleFlowUITests: XCTestCase {
    @MainActor
    func testScheduleThenTrainFromPlan() throws {
        try runScheduleFlow(inEnglish: false)
    }

    @MainActor
    func testScheduleThenTrainFromPlanInEnglish() throws {
        try runScheduleFlow(inEnglish: true)
    }

    // MARK: - 旅程本體

    @MainActor
    private func runScheduleFlow(inEnglish: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = uitestLaunchArguments(inEnglish ? ["--uitest-language=en"] : [])
        app.launch()

        // 先確認語言真的切了。
        //
        // 這條不能省：測試主體只用 identifier，跟語言無關——所以 `--uitest-language=en` 萬一
        // 失效（參數改名、seed 邏輯變動），英文版會**照樣全過**，變成一支假的英文覆蓋。
        // 同樣形狀的假通過在 PR #54 發生過一次。
        let trainingTab = app.buttons["tabBar.item.training"]
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 10), "找不到自訂分頁列")
        XCTAssertEqual(
            Self.containsHan(trainingTab.label), !inEnglish,
            "App 語言不是預期的那個（分頁標籤＝「\(trainingTab.label)」，inEnglish=\(inEnglish)）"
        )

        let benchPress = "測試臥推"
        let squat = "測試深蹲"
        let planName = "測試推日"

        addExercise(app, name: benchPress)
        addExercise(app, name: squat)

        // 課表：新增一個含兩個動作、當日（預設今天）的排課
        app.buttons["tabBar.item.plan"].tap()
        app.buttons["plan.new"].tap()
        app.buttons["plan.addBlank"].tap()
        let nameField = app.textFields["editScaffold.title"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(planName)
        addExerciseToPlan(app, name: benchPress)
        addExerciseToPlan(app, name: squat)
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
        assertSetRecorded(app)
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
        assertSetRecorded(app)

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

    /// 有組被記錄下來了。
    ///
    /// 比原本斷言「第1組」強：那段文字在完成前後都在（當前組與已完成的組各有一個節點），
    /// 所以完成與否都會通過。這裡只認「已完成」那個節點。
    @MainActor private func assertSetRecorded(
        _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(
            app.staticTexts["activeWorkout.completedSet"].firstMatch.waitForExistence(timeout: 5),
            "沒有任何已完成的組",
            file: file, line: line
        )
    }

    /// 是否含 CJK 統一表意文字（含擴充 A）。標點與英數不算。
    private static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    @MainActor private func addExercise(_ app: XCUIApplication, name: String) {
        app.buttons["tabBar.item.exercises"].tap()
        app.buttons["library.add"].tap()
        let field = app.textFields["editScaffold.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["editScaffold.save"].tap()
        app.searchExerciseList(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.clearExerciseListSearch()
    }

    @MainActor private func addExerciseToPlan(_ app: XCUIApplication, name: String) {
        // 空白排課表單用 PickerSheet（多選）：搜尋 → 點名字選取 → 按確認鈕。
        app.buttons["planForm.addExercise"].tap()
        app.pickExercise(name)
        app.buttons["picker.confirm"].tap()
    }
}
