import XCTest

/// 動作庫與「選動作」picker 的共用操作。
///
/// 為什麼不再直接 `app.staticTexts["臥推"].tap()`：內建動作清單（`OfficialExerciseCatalog`，80 筆）
/// 常駐在動作庫與每一個 picker 裡，所以
/// 1. 名稱可能撞（測試自己建的動作要取不會跟內建撞的名字），且
/// 2. 目標可能被擠到畫面外——`LazyVStack` 沒算繪的列連查都查不到，更別說點。
///
/// 一律先用搜尋把清單縮到只剩目標再操作，就跟畫面上有幾筆動作無關了。
///
/// 搜尋列用 identifier 而不是 placeholder 文字定位：三個搜尋列的 placeholder 都是「搜尋動作」，
/// 拿文字找不但綁死語言，picker 疊在動作庫上時還會打到背後那一個。
extension XCUIApplication {
    /// 在動作庫清單的搜尋列輸入關鍵字。
    @MainActor func searchExerciseList(
        _ keyword: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        type(keyword, into: "exerciseList.search", file: file, line: line)
    }

    /// 清掉動作庫清單的搜尋條件。留著沒清會讓後續在同一頁的斷言被過濾掉。
    @MainActor func clearExerciseListSearch() {
        let clear = buttons["exerciseList.search.clear"].firstMatch
        if clear.waitForExistence(timeout: 2) { clear.tap() }
    }

    /// 在「選動作」picker 裡搜尋並點選指定動作。
    ///
    /// 動作名是測試自己輸入的資料，與介面語言無關，所以這裡用文字定位是對的。
    @MainActor func pickExercise(
        _ name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        type(name, into: "picker.search", file: file, line: line)
        let row = staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "picker 裡找不到「\(name)」", file: file, line: line)
        row.tap()
    }

    @MainActor private func type(
        _ text: String, into identifier: String, file: StaticString, line: UInt
    ) {
        let field = textFields[identifier].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "找不到搜尋列 \(identifier)", file: file, line: line)
        field.tap()
        field.typeText(text)
    }
}

// MARK: - 各測試共用的建置步驟

/// 「先建個動作 → 排進課表 → 去訓練頁開練」這串前置動作在十幾個測試裡逐字重複。
/// 抽成共用操作之後，identifier 只會出現在這裡一份，畫面改版時只有一個地方要改。
extension XCUIApplication {
    /// 動作庫建一個動作（名稱是測試自己輸入的資料，與介面語言無關）。
    @MainActor func addExercise(
        named name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        buttons["tabBar.item.exercises"].tap()
        buttons["library.add"].tap()
        let field = textFields["editScaffold.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "動作表單沒開", file: file, line: line)
        field.tap()
        field.typeText(name)
        buttons["editScaffold.save"].tap()
        searchExerciseList(name, file: file, line: line)
        XCTAssertTrue(staticTexts[name].waitForExistence(timeout: 5), "動作沒建成功", file: file, line: line)
        clearExerciseListSearch()
    }

    /// 排課表單裡加一個動作：PickerSheet 是多選，選完要按確認鈕。
    @MainActor func addExerciseToPlan(
        named name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        buttons["planForm.addExercise"].tap()
        pickExercise(name, file: file, line: line)
        buttons["picker.confirm"].tap()
    }

    /// 課表分頁：空白建立一份當日排課，名稱與動作都由呼叫端給。
    ///
    /// `configure` 在存檔前呼叫，給需要再調整逐組設定（休息秒數、組數）的測試用。
    @MainActor func createBlankPlan(
        named planName: String, exercises: [String],
        file: StaticString = #filePath, line: UInt = #line,
        configure: (XCUIApplication) -> Void = { _ in }
    ) {
        buttons["tabBar.item.plan"].tap()
        buttons["plan.new"].tap()
        buttons["plan.addBlank"].tap()   // 「+」選單 → 空白建立
        let field = textFields["editScaffold.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "排課表單沒開", file: file, line: line)
        field.tap()
        field.typeText(planName)
        for name in exercises {
            addExerciseToPlan(named: name, file: file, line: line)
        }
        configure(self)
        buttons["editScaffold.save"].tap()
        XCTAssertTrue(
            staticTexts[planName].waitForExistence(timeout: 5), "排課沒存成功", file: file, line: line
        )
    }

    /// 排課表單裡把某個動作的組間休息往上加 `steps` 階（stepper 一階 15 秒，預設 0＝不設）。
    /// 給 `createBlankPlan(configure:)` 用。
    @MainActor func raiseRest(
        onPlanExercise name: String, steps: Int = 1,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        staticTexts[name].firstMatch.tap()   // 點動作列開逐組編輯 sheet
        let stepper = steppers["planForm.restStepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "逐組編輯 sheet 沒開", file: file, line: line)
        for _ in 0..<steps {
            stepper.buttons.element(boundBy: 1).tap()   // boundBy 1 ＝ ＋
        }
        buttons["compactSheet.confirm"].tap()
    }

    /// 訓練分頁 → 開始今天的排課。13d 的開練前預覽 sheet 要再確認一次才真正落地。
    @MainActor func startTodaysPlan(file: StaticString = #filePath, line: UInt = #line) {
        buttons["tabBar.item.training"].tap()
        let start = buttons["training.startCard"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "訓練頁沒有今天的排課", file: file, line: line)
        start.tap()
        let confirm = buttons["trainingPreview.start"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "開練前預覽沒開", file: file, line: line)
        confirm.tap()
    }

    /// 訓練分頁 → 自由訓練，並在選動作 sheet 裡挑一個動作。
    @MainActor func startFreeTraining(
        with exerciseName: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        buttons["tabBar.item.training"].tap()
        buttons["training.startFree"].tap()
        // 開場會自動彈選動作 sheet；保險起見沒彈出就手動點空狀態的「加入動作」。
        let picker = staticTexts["picker.title"]
        if !picker.waitForExistence(timeout: 3) {
            buttons["activeWorkout.addExercise"].tap()
            XCTAssertTrue(picker.waitForExistence(timeout: 5), "選動作 sheet 沒開", file: file, line: line)
        }
        pickExercise(exerciseName, file: file, line: line)
    }

    /// 已完成的組數。
    ///
    /// 比斷言「第N組」可靠：那段文字在「目前這組」與「已完成的組」各有一個節點，
    /// 所以完成與否都會命中——這裡只數已完成的那種。
    @MainActor var completedSetCount: Int {
        staticTexts.matching(identifier: "activeWorkout.completedSet").count
    }

    /// 至少有一組被記錄下來了。
    @MainActor func waitForCompletedSet(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            staticTexts["activeWorkout.completedSet"].firstMatch.waitForExistence(timeout: 5),
            "沒有任何已完成的組", file: file, line: line
        )
    }

    /// 等待「目前停在第 n 組」。測試靠它判斷有沒有多記／少記一組。
    @MainActor func waitForCurrentSet(
        _ n: Int, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(
            staticTexts["activeWorkout.currentSet.\(n)"].waitForExistence(timeout: timeout),
            "目前這組應該是第 \(n) 組", file: file, line: line
        )
    }
}
