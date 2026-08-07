import XCTest

/// 長期課表（N 天週期 + 投影，設計稿 12b）：動作庫建一個含動作的範本 → 長期「+」直接開建立頁 →
/// 打名字 → 逐天指派範本或「休息」（新增模式必須全部決定過才能儲存）→ 課表 tab 套用（起始日＝今天）
/// → 當日詳情出現投影「推日」＋「加入這天」。
final class ProgramFlowUITests: XCTestCase {
    @MainActor
    func testBuildProgramThenApplyShowsProjection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 動作庫：建動作
        app.buttons["動作庫"].tap()
        app.buttons["library.add"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap(); nameField.typeText("測試臥推")
        app.buttons["儲存"].tap()
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        app.clearExerciseListSearch()

        // 範本分段：建一個含測試臥推的課表範本（長期現在每天指派的是範本，見設計稿 12b）
        app.buttons["範本"].tap()
        app.buttons["library.add"].tap()
        let templateName = app.textFields["範本名稱"]
        XCTAssertTrue(templateName.waitForExistence(timeout: 5))
        templateName.tap(); templateName.typeText("推日")
        app.buttons["從動作庫加入"].tap()
        app.pickExercise("測試臥推")
        app.buttons["加入 1 個動作"].tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 長期分段：「+」直接開建立頁 → 打名字
        app.buttons["長期"].tap()
        app.buttons["library.add"].tap()
        let programTitle = app.textFields["名稱（例：PPL）"]
        XCTAssertTrue(programTitle.waitForExistence(timeout: 5))
        programTitle.tap(); programTitle.typeText("測試課表")

        // 第 1 天指派範本；預設週期 7 天，新增模式要全部決定過才能儲存——其餘 6 天設為休息。
        // 每次決定完，「下一個要填的格」會反白出現同一句提示文字，重複點它即可逐天推進。
        let nextPrompt = app.staticTexts["選一個範本，或設為休息"]
        XCTAssertTrue(nextPrompt.waitForExistence(timeout: 5))
        nextPrompt.tap()
        let pick = app.staticTexts["推日"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        for _ in 0..<6 {
            let prompt = app.staticTexts["選一個範本，或設為休息"]
            XCTAssertTrue(prompt.waitForExistence(timeout: 5))
            prompt.tap()
            let rest = app.staticTexts["設為休息"]
            XCTAssertTrue(rest.waitForExistence(timeout: 5))
            rest.tap()
        }

        app.buttons["儲存"].tap()

        // 課表 tab → 套用長期課表（起始日預設今天、模式預設重複）
        app.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        let applyMenuItem = app.buttons["套用長期課表"]
        XCTAssertTrue(applyMenuItem.waitForExistence(timeout: 5))
        applyMenuItem.tap()
        let applyButton = app.buttons["套用"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        applyButton.tap()

        // 當日詳情：出現投影「推日」＋「加入這天」
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        let addThisDay = app.buttons["加入這天"]
        XCTAssertTrue(addThisDay.waitForExistence(timeout: 5))
        addThisDay.tap()
        // 落地後仍看得到「推日」（已是真實排課）
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
    }
}
