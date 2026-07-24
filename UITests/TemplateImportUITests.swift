import XCTest

/// 「從範本帶入」：循環課表 / 長期課表的 workout 可直接複製一份課表範本進來（copy 快照）。
/// 這裡驗證循環課表這條路徑（長期課表共用同一個 WorkoutSpecFormView）。
final class TemplateImportUITests: XCTestCase {
    @MainActor
    func testImportTemplateIntoRotationWorkout() throws {
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

        // 範本分段：建一個含臥推的課表範本
        app.segmentedControls.buttons["範本"].tap()
        app.buttons["新增範本"].tap()
        let templateName = app.textFields["範本名稱"]
        XCTAssertTrue(templateName.waitForExistence(timeout: 5))
        templateName.tap(); templateName.typeText("胸推範本")
        app.buttons["加入動作"].tap()
        let pick = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["胸推範本"].waitForExistence(timeout: 5))

        // 循環分段：建一組循環 → 進去加 workout → 從範本帶入
        app.segmentedControls.buttons["循環"].tap()
        app.buttons["新增循環課表"].tap()
        let rotationName = app.textFields["名稱（例：推拉腿）"]
        XCTAssertTrue(rotationName.waitForExistence(timeout: 5))
        rotationName.tap(); rotationName.typeText("測試循環")
        app.buttons["儲存"].tap()
        app.staticTexts["測試循環"].tap()

        app.buttons["加入循環 workout"].tap()
        let importButton = app.buttons["從範本帶入"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()
        // 選單出現範本 → 點它帶入
        let menuItem = app.buttons["胸推範本"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.tap()
        // 帶入後名稱自動填「胸推範本」、動作已帶臥推 → 儲存
        app.buttons["儲存"].tap()

        // 循環清單裡出現這張帶入的 workout
        XCTAssertTrue(app.staticTexts["胸推範本"].waitForExistence(timeout: 5))
    }
}
