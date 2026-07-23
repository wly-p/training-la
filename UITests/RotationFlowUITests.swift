import XCTest

/// 循環課表（2b）：在課表建立一組循環 → 訓練首頁「今天輪到 X」→ 開始循環進入記錄。
final class RotationFlowUITests: XCTestCase {
    @MainActor
    func testBuildRotationThenStartFromHome() throws {
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

        // 課表 → 循環課表編輯器 → 加入一張循環 workout
        app.tabBars.buttons["課表"].tap()
        app.buttons["循環課表"].tap()
        let addWorkout = app.buttons["加入循環 workout"]
        XCTAssertTrue(addWorkout.waitForExistence(timeout: 5))
        addWorkout.tap()
        let workoutName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(workoutName.waitForExistence(timeout: 5))
        workoutName.tap(); workoutName.typeText("推日")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()

        // 訓練首頁：出現「循環課表今天輪到 推日」＋ 開始
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["開始今天的循環"].tap()

        // 記錄畫面：自動選到循環的動作（臥推）
        XCTAssertTrue(app.navigationBars["臥推"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))
    }
}
