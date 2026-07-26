import XCTest

/// 循環課表（可多組並行，設計稿 12a）：動作庫建一個含動作的範本 → 循環「+」直接開建立頁
/// （新增／編輯同一頁）→ 打名字 → 從範本加入 → 訓練首頁「隨時可做」卡出現該組今天的 workout
/// → 開始循環進入記錄。
final class RotationFlowUITests: XCTestCase {
    @MainActor
    func testBuildRotationThenStartFromHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 動作庫：建動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["libraryAddButton"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap(); nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 範本分段：建一個含臥推的課表範本（循環現在只能從範本匯入內容，見設計稿 12a）
        app.buttons["範本"].tap()
        app.buttons["libraryAddButton"].tap()
        let templateName = app.textFields["範本名稱"]
        XCTAssertTrue(templateName.waitForExistence(timeout: 5))
        templateName.tap(); templateName.typeText("推日")
        app.buttons["從動作庫加入"].tap()
        app.staticTexts["臥推"].firstMatch.tap()
        app.buttons["加入 1 個動作"].tap()
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))

        // 循環分段：「+」直接開建立頁（新增／編輯同一頁）→ 打名字 → 加入範本
        app.buttons["循環"].tap()
        app.buttons["libraryAddButton"].tap()
        let rotationTitle = app.textFields["名稱（例：推拉腿）"]
        XCTAssertTrue(rotationTitle.waitForExistence(timeout: 5))
        rotationTitle.tap(); rotationTitle.typeText("推拉腿")
        app.buttons["加入範本"].tap()
        let pick = app.staticTexts["推日"].firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["加入 1 個範本"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["儲存"].tap()

        // 訓練首頁：「隨時可做」卡標題顯示今天輪到的 workout 名（推日）
        app.tabBars.buttons["訓練"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["開始循環"].tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["開始訓練"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()

        // 記錄畫面：自動選到循環的動作（臥推）
        XCTAssertTrue(app.navigationBars["臥推"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))
    }
}
