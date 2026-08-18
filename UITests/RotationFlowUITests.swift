import XCTest

/// 循環課表（可多組並行，設計稿 12a）：動作庫建一個含動作的範本 → 循環「+」直接開建立頁
/// （新增／編輯同一頁）→ 打名字 → 從範本加入 → 訓練首頁「隨時可做」卡出現該組今天的 workout
/// → 開始循環進入記錄。
final class RotationFlowUITests: XCTestCase {
    @MainActor
    func testBuildRotationThenStartFromHome() throws {
        let app = XCUIApplication()
        launchForUITest(app)

        app.addExercise(named: "測試臥推")
        // 循環現在只能從範本匯入內容（見設計稿 12a），所以先建一個範本
        app.addTemplate(named: "推日", exercise: "測試臥推")

        // 循環分段：「+」直接開建立頁（新增／編輯同一頁）→ 打名字 → 加入範本
        app.buttons["library.segment.rotation"].tap()
        app.buttons["library.add"].tap()
        let rotationTitle = app.textFields["editScaffold.title"]
        XCTAssertTrue(rotationTitle.waitForExistence(timeout: 5))
        rotationTitle.tap(); rotationTitle.typeText("推拉腿")
        app.buttons["rotationEditor.addTemplate"].tap()
        let pick = app.staticTexts["推日"].firstMatch   // 範本名是測試自己輸入的資料
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["picker.confirm"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["editScaffold.save"].tap()

        // 訓練首頁：「隨時可做」卡標題顯示今天輪到的 workout 名（推日）
        app.buttons["tabBar.item.training"].tap()
        XCTAssertTrue(app.staticTexts["推日"].waitForExistence(timeout: 5))
        app.buttons["training.startRotation"].tap()
        // 13d 開練前預覽 sheet：確認開始才真正落地
        let confirmStart = app.buttons["trainingPreview.start"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5))
        confirmStart.tap()

        // 記錄畫面：自動選到循環的動作（測試臥推）
        XCTAssertTrue(app.navigationBars["測試臥推"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["activeWorkout.completeSet"].waitForExistence(timeout: 5))
    }
}
