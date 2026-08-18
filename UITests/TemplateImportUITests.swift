import XCTest

/// 共用選擇器 sheet（設計稿 12c/12d）：循環「加入範本」的搜尋過濾＋多選一次加入。
/// 這裡驗證 picker 本身的行為（搜尋只留相符範本、多選累計、確認後兩個都進清單），
/// 跟 RotationFlowUITests 的端到端建立流程分開測。
final class TemplateImportUITests: XCTestCase {
    @MainActor
    func testPickerSearchFiltersAndMultiSelectAddsAll() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        // 動作庫：建兩個動作
        app.addExercise(named: "測試臥推")
        app.addExercise(named: "測試深蹲")

        // 範本分段：建兩個範本，各帶一個動作
        app.addTemplate(named: "推日", exercise: "測試臥推")
        app.addTemplate(named: "腿日", exercise: "測試深蹲")

        // 循環分段：開建立頁 → 開「加入範本」picker
        app.buttons["library.segment.rotation"].tap()
        app.buttons["library.add"].tap()
        let rotationTitle = app.textFields["editScaffold.title"]
        XCTAssertTrue(rotationTitle.waitForExistence(timeout: 5))
        rotationTitle.tap(); rotationTitle.typeText("測試循環")
        app.buttons["rotationEditor.addTemplate"].tap()

        // 搜尋「推」只留「推日」，「腿日」被濾掉（範本名是測試自己輸入的資料）
        let searchField = app.textFields["picker.search"]
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

        // 底部按鈕帶已選數量（「加入 2 個範本」），文字會跟著語言與數量變，所以認 id。
        let confirmButton = app.buttons["picker.confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // 循環編輯頁的清單裡兩個範本都出現
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["腿日"].waitForExistence(timeout: 5))
        app.buttons["editScaffold.save"].tap()
    }
}
