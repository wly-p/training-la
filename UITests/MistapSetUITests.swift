import XCTest

/// bug③：訓練中誤觸畫面會直接跳到下一組。
///
/// 記錄輸入面板（重量/次數 steppers + 完成/跳過/休息）是一個含多個控制項的 List cell。
/// 修復前，「跳過此組」用預設 button style，SwiftUI 會把整個 cell 空白處的點擊都轉發給它，
/// 於是點步進器周圍、標籤等空白處就會多記一組（狀態 .skipped）。
/// 這個測試點面板中的非控制項文字（組表的「目標」「實際」欄名），驗證不會記錄任何組。
final class MistapSetUITests: XCTestCase {
    @MainActor
    func testTappingEmptyEditorAreaDoesNotRecordSet() throws {
        let app = XCUIApplication()
        launchForUITest(app) // 乾淨的 in-memory store

        app.addExercise(named: "測試臥推")
        app.startFreeTraining(with: "測試臥推")

        // 記錄面板出現、尚未記任何組
        XCTAssertTrue(app.buttons["activeWorkout.completeSet"].waitForExistence(timeout: 5))
        app.waitForCurrentSet(1)

        // 點面板內的非控制項（組表欄名）——不應觸發任何記錄動作
        app.staticTexts["activeWorkout.targetColumn"].tap()
        app.staticTexts["activeWorkout.actualColumn"].tap()

        // 沒有被多記一組：仍停在第 1 組。
        // （修復前這裡會誤觸「跳過此組」多記一組，變成第 2 組而失敗。）
        XCTAssertFalse(
            app.staticTexts["activeWorkout.currentSet.2"].waitForExistence(timeout: 2),
            "點記錄面板空白處不應記錄任何組"
        )
        XCTAssertEqual(app.completedSetCount, 0)
    }
}
