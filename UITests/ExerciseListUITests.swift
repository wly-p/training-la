import XCTest

final class ExerciseListUITests: XCTestCase {
    @MainActor
    func testAddExerciseShowsUpInList() throws {
        let app = XCUIApplication()
        launchForUITest(app) // 乾淨的 in-memory store

        app.buttons["tabBar.item.exercises"].tap()
        app.buttons["library.add"].tap()

        let nameField = app.textFields["editScaffold.title"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("測試臥推")
        app.buttons["editScaffold.save"].tap() // 器材用預設（槓鈴）

        // 內建動作清單（80 筆）常駐，先搜尋縮到只剩剛建的那筆再驗——不然下面的器材標
        // 會被一堆內建動作的器材標籤誤打誤撞地滿足，等於沒測到。
        app.searchExerciseList("測試臥推")
        XCTAssertTrue(app.staticTexts["測試臥推"].waitForExistence(timeout: 5))
        // 列表列掛著器材標 → 證明 equipment 有存進去並顯示。
        // 標上的字（預設是槓鈴）會跟著語言換，所以只驗元件在，不驗文字。
        XCTAssertTrue(app.staticTexts["equipmentTag"].firstMatch.waitForExistence(timeout: 5))

        // 長按列叫出 context menu → 刪除（DesignSystem 容器非原生 List，無 swipe）
        app.staticTexts["測試臥推"].press(forDuration: 1.0)
        let deleteButton = app.buttons["exerciseList.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // 刪掉之後這個搜尋字就沒東西命中了。動作庫本身不會變空——內建清單還在，
        // 所以這裡等的是「搜尋無結果」的空狀態。
        XCTAssertTrue(app.staticTexts["exerciseList.empty"].waitForExistence(timeout: 5))
    }

    /// 內建動作是唯讀的：長按不給刪除選單。
    @MainActor
    func testBuiltInExerciseIsReadOnly() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.buttons["tabBar.item.exercises"].tap()

        // 全新的 in-memory store 也看得到內建動作——它們不進 DB，是常駐清單。
        //
        // 不能用名字找：內建動作的名稱跟著 app 語言換（臥推／Bench Press）。改認唯讀列的 id，
        // 順帶也把「這一列真的被標成內建」一起驗到了。
        let builtIn = app.descendants(matching: .any)["exerciseList.officialRow"].firstMatch
        XCTAssertTrue(builtIn.waitForExistence(timeout: 5), "內建動作應該出現在動作庫")

        builtIn.press(forDuration: 1.0)
        XCTAssertFalse(
            app.buttons["exerciseList.delete"].waitForExistence(timeout: 2),
            "內建動作不該有刪除選項"
        )
    }
}
