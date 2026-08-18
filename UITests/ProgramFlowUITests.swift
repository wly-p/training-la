import XCTest

/// 長期課表（N 天週期 + 投影，設計稿 12b）：動作庫建一個含動作的範本 → 長期「+」直接開建立頁 →
/// 打名字 → 逐天指派範本或「休息」（新增模式必須全部決定過才能儲存）→ 課表 tab 套用（起始日＝今天）
/// → 當日詳情出現投影「推日」＋「加入這天」。
final class ProgramFlowUITests: XCTestCase {
    @MainActor
    func testBuildProgramThenApplyShowsProjection() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        // 長期每天指派的是範本（見設計稿 12b），所以先建一個
        app.addTemplate(named: "推日", exercise: "測試臥推")

        // 長期分段：「+」直接開建立頁 → 打名字
        app.buttons["library.segment.program"].tap()
        app.buttons["library.add"].tap()
        let programTitle = app.textFields["editScaffold.title"]
        XCTAssertTrue(programTitle.waitForExistence(timeout: 5))
        programTitle.tap(); programTitle.typeText("測試課表")

        // 第 1 天指派範本；預設週期 7 天，新增模式要全部決定過才能儲存——其餘 6 天設為休息。
        // 列的標題會隨狀態換文案，所以用「第幾天」這個不變量定位。
        app.buttons["programEditor.day.1"].tap()
        let pick = app.staticTexts["推日"].firstMatch   // 範本名是測試自己輸入的資料
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        for day in 2...7 {
            let row = app.buttons["programEditor.day.\(day)"]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
            // 「休息」是本地化的合成選項（不是使用者資料），所以認 id。
            let rest = app.staticTexts["picker.row.rest"].firstMatch
            XCTAssertTrue(rest.waitForExistence(timeout: 5))
            rest.tap()
        }

        app.buttons["editScaffold.save"].tap()

        // 課表 tab → 套用長期課表（起始日預設今天、模式預設重複）
        app.buttons["tabBar.item.plan"].tap()
        app.buttons["plan.new"].tap()
        let applyMenuItem = app.buttons["plan.applyProgram"]
        XCTAssertTrue(applyMenuItem.waitForExistence(timeout: 5))
        applyMenuItem.tap()
        let applyButton = app.buttons["programApply.confirm"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        applyButton.tap()

        // 當日詳情：出現投影「推日」＋「加入這天」
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        let addThisDay = app.buttons["plan.addThisDay"]
        XCTAssertTrue(addThisDay.waitForExistence(timeout: 5))
        addThisDay.tap()
        // 落地後仍看得到「推日」（已是真實排課）
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
    }
}
