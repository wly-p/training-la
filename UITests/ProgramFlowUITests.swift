import XCTest

/// 長期課表（N 天週期 + 投影）：動作庫建立一份課表 → 指定第 1 天的 workout →
/// 課表 tab 套用（起始日＝今天）→ 當日詳情出現投影「推日」＋「加入這天」。
final class ProgramFlowUITests: XCTestCase {
    @MainActor
    func testBuildProgramThenApplyShowsProjection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 動作庫：建動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap(); nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 動作庫 → 「長期」分段 → 新增一份長期課表
        app.segmentedControls.buttons["長期"].tap()
        let newProgram = app.buttons["新增長期課表"]
        XCTAssertTrue(newProgram.waitForExistence(timeout: 5))
        newProgram.tap()
        let programName = app.textFields["名稱（例：PPL）"]
        XCTAssertTrue(programName.waitForExistence(timeout: 5))
        programName.tap(); programName.typeText("測試課表")
        app.buttons["儲存"].tap()

        // 點進課表 → 指定第 1 天的 workout
        let programRow = app.staticTexts["測試課表"]
        XCTAssertTrue(programRow.waitForExistence(timeout: 5))
        programRow.tap()
        let firstDay = app.staticTexts["第 1 天"]
        XCTAssertTrue(firstDay.waitForExistence(timeout: 5))
        firstDay.tap()
        let workoutName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(workoutName.waitForExistence(timeout: 5))
        workoutName.tap(); workoutName.typeText("推日")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 課表 tab → 套用長期課表（起始日預設今天、模式預設重複）
        app.tabBars.buttons["課表"].tap()
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
