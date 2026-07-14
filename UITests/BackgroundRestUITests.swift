import XCTest

/// bug①：組間休息倒數切到其他 App 會暫停。
/// 倒數改以「結束時間 + 切回前景重算」為準，App 進背景不會暫停。
/// 這個測試在休息中把 App 切到背景、待休息時間過完再切回，驗證休息已結束（沒有被暫停）。
final class BackgroundRestUITests: XCTestCase {
    @MainActor
    func testRestKeepsCountingWhileAppInBackground() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 動作庫建一個動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 課表：休息設 5 秒
        app.tabBars.buttons["課表"].tap()
        app.buttons["新增排課"].tap()
        let planName = app.textFields["名稱（例：推日）"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("背景測試")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        let restField = app.textFields["秒（可留空）"]
        XCTAssertTrue(restField.waitForExistence(timeout: 5))
        restField.tap()
        restField.typeText("5")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["背景測試"].waitForExistence(timeout: 5))

        // 照課表訓練，完成一組 → 進入休息
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.buttons["照課表開始"].waitForExistence(timeout: 5))
        app.buttons["照課表開始"].tap()
        let completeButton = app.buttons["完成此組"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["休息中"].waitForExistence(timeout: 3))

        // 切到背景，待超過休息時間（5 秒）再切回
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 7)
        app.activate()

        // 切回前景後：休息已結束（沒有被暫停）→ 出現「休息結束」彈窗
        XCTAssertTrue(
            app.staticTexts["休息結束"].waitForExistence(timeout: 5),
            "背景期間倒數應持續進行，切回時休息應已結束"
        )
    }
}
