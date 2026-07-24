import XCTest

/// 循環課表（可多組並行）：動作庫建立一組具名循環 → 進去加一張 workout →
/// 訓練首頁顯示該組「今天輪到 X」→ 開始循環進入記錄。
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

        // 動作庫 → 切到「循環課表」分段 → 新增一組具名循環
        app.segmentedControls.buttons["循環課表"].tap()
        let newRotation = app.buttons["新增循環課表"]
        XCTAssertTrue(newRotation.waitForExistence(timeout: 5))
        newRotation.tap()
        let rotationName = app.textFields["名稱（例：推拉腿）"]
        XCTAssertTrue(rotationName.waitForExistence(timeout: 5))
        rotationName.tap(); rotationName.typeText("推拉腿")
        app.buttons["儲存"].tap()

        // 點進這組循環 → 加入一張循環 workout
        let rotationRow = app.staticTexts["推拉腿"]
        XCTAssertTrue(rotationRow.waitForExistence(timeout: 5))
        rotationRow.tap()
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

        // 訓練首頁：出現該組「今天輪到 推日」＋ 開始
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["開始今天的循環"].tap()

        // 記錄畫面：自動選到循環的動作（臥推）
        XCTAssertTrue(app.navigationBars["臥推"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))
    }
}
