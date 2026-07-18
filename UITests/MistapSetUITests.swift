import XCTest

/// bug③：訓練中誤觸畫面會直接跳到下一組。
///
/// 記錄輸入面板（重量/次數 steppers + 完成/跳過/休息）是一個含多個控制項的 List cell。
/// 修復前，「跳過此組」用預設 button style，SwiftUI 會把整個 cell 空白處的點擊都轉發給它，
/// 於是點步進器周圍、標籤等空白處就會多記一組（狀態 .skipped）。
/// 這個測試點面板中的非控制項文字（「重量」「次數」標籤），驗證不會記錄任何組。
final class MistapSetUITests: XCTestCase {
    @MainActor
    func testTappingEmptyEditorAreaDoesNotRecordSet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"] // 乾淨的 in-memory store
        app.launch()

        // 1. 動作庫建一個動作
        app.tabBars.buttons["動作庫"].tap()
        app.buttons["新增動作"].tap()
        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("臥推")
        app.buttons["儲存"].tap()
        XCTAssertTrue(app.staticTexts["臥推"].waitForExistence(timeout: 5))

        // 2. 開始訓練 → 選動作 → 進入記錄面板
        app.tabBars.buttons["訓練"].tap()
        app.buttons["開始訓練"].tap()
        let pickerTitle = app.navigationBars["選擇動作"]
        if !pickerTitle.waitForExistence(timeout: 3) {
            app.buttons["加入動作"].tap()
            XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5))
        }
        let pickerRow = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(pickerRow.waitForExistence(timeout: 5))
        pickerRow.tap()

        // 3. 記錄面板出現、尚未記任何組（header 顯示「第1組」）
        XCTAssertTrue(app.buttons["完成此組"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["第1組"].waitForExistence(timeout: 5))

        // 4. 點面板內的非控制項空白處（重量／次數標籤）——修復後不應觸發任何動作
        app.staticTexts["重量"].tap()
        app.staticTexts["次數"].tap()

        // 5. 沒有被多記一組：header 仍停在「第1組」，不會出現「第2組」
        //    （修復前這裡會誤觸「跳過此組」多記一組，header 變「第2組」而失敗。）
        XCTAssertFalse(
            app.staticTexts["第2組"].waitForExistence(timeout: 2),
            "點記錄面板空白處不應記錄任何組"
        )
    }
}
