import XCTest

/// 共用選擇器 sheet（設計稿 12c/12d）：循環「加入範本」的搜尋過濾＋多選一次加入。
/// 這裡驗證 picker 本身的行為（搜尋只留相符範本、多選累計、底部按鈕依已選數量變文字），
/// 跟 RotationFlowUITests 的端到端建立流程分開測。
final class TemplateImportUITests: XCTestCase {
    @MainActor
    func testPickerSearchFiltersAndMultiSelectAddsAll() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        // 動作庫：建兩個動作
        app.buttons["動作庫"].tap()
        for name in ["臥推", "深蹲"] {
            app.buttons["libraryAddButton"].tap()
            let nameField = app.textFields["名稱（例：臥推）"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap(); nameField.typeText(name)
            app.buttons["儲存"].tap()
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        }

        // 範本分段：建兩個範本，各帶一個動作
        app.buttons["範本"].tap()
        for (templateName, exerciseName) in [("推日", "臥推"), ("腿日", "深蹲")] {
            app.buttons["libraryAddButton"].tap()
            let field = app.textFields["範本名稱"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap(); field.typeText(templateName)
            app.buttons["從動作庫加入"].tap()
            app.staticTexts[exerciseName].firstMatch.tap()
            app.buttons["加入 1 個動作"].tap()
            app.buttons["儲存"].tap()
            XCTAssertTrue(app.staticTexts[templateName].waitForExistence(timeout: 5))
        }

        // 循環分段：開建立頁 → 開「加入範本」picker
        app.buttons["循環"].tap()
        app.buttons["libraryAddButton"].tap()
        let rotationTitle = app.textFields["名稱（例：推拉腿）"]
        XCTAssertTrue(rotationTitle.waitForExistence(timeout: 5))
        rotationTitle.tap(); rotationTitle.typeText("測試循環")
        app.buttons["加入範本"].tap()

        // 搜尋「推」只留「推日」，「腿日」被濾掉
        let searchField = app.textFields["搜尋範本"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("推")
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["腿日"].exists)

        // 清空搜尋（退格鍵刪掉剛打的字），兩個範本都出現 → 多選兩個
        searchField.typeText("\u{8}")
        XCTAssertTrue(app.staticTexts["腿日"].waitForExistence(timeout: 5))
        app.staticTexts["推日"].firstMatch.tap()
        app.staticTexts["腿日"].firstMatch.tap()

        // 底部按鈕依已選數量顯示「加入 2 個範本」
        let confirmButton = app.buttons["加入 2 個範本"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // 循環編輯頁的清單裡兩個範本都出現
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["腿日"].waitForExistence(timeout: 5))
        app.buttons["儲存"].tap()
    }
}
