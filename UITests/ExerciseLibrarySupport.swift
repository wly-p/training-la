import XCTest

/// 動作庫與「選動作」picker 的共用操作。
///
/// 為什麼不再直接 `app.staticTexts["臥推"].tap()`：內建動作清單（`OfficialExerciseCatalog`，80 筆）
/// 常駐在動作庫與每一個 picker 裡，所以
/// 1. 名稱可能撞（測試自己建的動作要取不會跟內建撞的名字），且
/// 2. 目標可能被擠到畫面外——`LazyVStack` 沒算繪的列連查都查不到，更別說點。
///
/// 一律先用搜尋把清單縮到只剩目標再操作，就跟畫面上有幾筆動作無關了。
extension XCUIApplication {
    /// 在動作庫／picker 的搜尋列輸入關鍵字。
    @MainActor func searchExercises(
        _ keyword: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let field = textFields["搜尋動作"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "找不到動作搜尋列", file: file, line: line)
        field.tap()
        field.typeText(keyword)
    }

    /// 清掉搜尋條件（搜尋列右側的 ✕）。留著沒清會讓後續在同一頁的斷言被過濾掉。
    @MainActor func clearExerciseSearch() {
        let clear = buttons["searchField.clear"].firstMatch
        if clear.waitForExistence(timeout: 2) { clear.tap() }
    }

    /// 在「選動作」picker 裡搜尋並點選指定動作。
    @MainActor func pickExercise(
        _ name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        searchExercises(name, file: file, line: line)
        let row = staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "picker 裡找不到「\(name)」", file: file, line: line)
        row.tap()
    }
}
