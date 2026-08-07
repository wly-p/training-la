import XCTest

final class ExerciseListUITests: XCTestCase {
    @MainActor
    func testAddExerciseShowsUpInList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"] // 乾淨的 in-memory store
        app.launch()

        app.buttons["動作庫"].tap()
        app.buttons["library.add"].tap()

        let nameField = app.textFields["名稱（例：臥推）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("測試臥推")
        app.buttons["儲存"].tap() // 器材用預設（槓鈴）

        // 內建動作清單（80 筆）常駐，先搜尋縮到只剩剛建的那筆再驗——不然下面的「槓鈴」
        // 會被一堆內建動作的器材標籤誤打誤撞地滿足，等於沒測到。
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        // 列表列顯示器材（預設槓鈴）→ 證明 equipment 有存進去並顯示
        XCTAssertTrue(app.staticTexts["槓鈴"].waitForExistence(timeout: 5))

        // 長按列叫出 context menu → 刪除（DesignSystem 容器非原生 List，無 swipe）
        app.staticTexts["測試臥推"].press(forDuration: 1.0)
        let deleteButton = app.buttons["刪除"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // 刪掉之後這個搜尋字就沒東西命中了。動作庫本身不會變空——內建清單還在，
        // 所以這裡等的是「搜尋無結果」而不是「還沒有動作」。
        XCTAssertTrue(app.staticTexts["找不到符合的動作"].waitForExistence(timeout: 5))
    }

    /// 內建動作是唯讀的：長按不給刪除選單。
    @MainActor
    func testBuiltInExerciseIsReadOnly() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()

        app.buttons["動作庫"].tap()
        // 全新的 in-memory store 也看得到內建動作——它們不進 DB，是常駐清單。
        app.searchExerciseList("臥推")
        let builtIn = app.staticTexts["臥推"].firstMatch
        XCTAssertTrue(builtIn.waitForExistence(timeout: 5), "內建動作應該出現在動作庫")

        builtIn.press(forDuration: 1.0)
        XCTAssertFalse(
            app.buttons["刪除"].waitForExistence(timeout: 2),
            "內建動作不該有刪除選項"
        )
    }
}
