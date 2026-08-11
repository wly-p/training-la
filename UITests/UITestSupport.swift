import Foundation
import XCTest

/// 這一輪要用的 app 語言，由 `xcodebuild test TEST_RUNNER_UITEST_APP_LANGUAGE=en` 注入
/// （`TEST_RUNNER_` 前綴會被 xcodebuild 剝掉再塞進測試 runner 的環境變數）。
///
/// 整套測試因此可以「同一份程式碼跑兩輪」，而不是每支 case 都寫中英兩份 func。
/// nil＝這一輪走 app 的預設語言（UI 測試模式下 seed 繁中，見 `AppDependencies`）。
let uitestAppLanguage: String? = ProcessInfo.processInfo.environment["UITEST_APP_LANGUAGE"]

/// 所有 UITest 共用的 launch arguments。
///
/// `--uitest-inmemory` 之外一定會帶 `--uitest-today=`：整輪 UITest 約 16 分鐘，
/// 只要有一個 test 的執行過程跨過午夜，就會出現「排課建在前一天、訓練頁查今天已是新的一天」
/// 的錯位，畫面掉進「今天沒有排課」空狀態而失敗（2026-08-09 23:45 那輪就踩到）。
/// 把日期在啟動前算好釘死，app 之後不管跑多久、跨不跨午夜，看到的都是同一天，
/// 跨午夜的視窗就從整個 test 的長度縮到「算完日期到 app 啟動」那幾毫秒。
///
/// 餵的是**當下的真實日期**而非寫死某一天：app 記錄 workout 時用的仍是真實時間戳，
/// 兩邊對得上，「本週練了幾次」「昨天」這類跟 today 比對的既有斷言才不會被弄壞。
///
/// `extra` 排在最前面是刻意的：app 端與下方的語言守衛都取**第一個**命中的
/// `--uitest-language=`，所以呼叫端明確指定的語言會蓋過這一輪的預設。
/// 需要這個的是「測語言切換本身」的 case——它必須從繁中開始，不能被英文那一輪帶走。
func uitestLaunchArguments(_ extra: [String] = []) -> [String] {
    var args = extra
    args.append("--uitest-inmemory")
    args.append("--uitest-today=\(uitestTodayArgumentValue())")
    if let uitestAppLanguage {
        args.append("--uitest-language=\(uitestAppLanguage)")
    }
    return args
}

/// 啟動 app 並確認語言真的是這一輪期望的那個。**所有 UITest 都該走這裡**。
///
/// 守衛不能省：測試主體改成 identifier 定位之後就跟語言無關了，所以
/// `--uitest-language=` 萬一失效（參數改名、seed 邏輯變動、環境變數沒進來），
/// 英文那一輪會**照樣全過**，變成一支假的英文覆蓋。同樣形狀的假通過在 PR #54 發生過一次。
@MainActor
func launchForUITest(
    _ app: XCUIApplication, extra: [String] = [],
    file: StaticString = #filePath, line: UInt = #line
) {
    let args = uitestLaunchArguments(extra)
    app.launchArguments = args
    app.launch()

    let expected = effectiveAppLanguage(args)
    let trainingTab = app.buttons["tabBar.item.training"]
    XCTAssertTrue(trainingTab.waitForExistence(timeout: 10), "找不到自訂分頁列", file: file, line: line)
    XCTAssertEqual(
        containsHan(trainingTab.label), expected != "en",
        "App 語言不是這一輪期望的（分頁標籤＝「\(trainingTab.label)」，期望 \(expected)）",
        file: file, line: line
    )
}

/// 是否含 CJK 統一表意文字（含擴充 A）。標點與英數不算。
func containsHan(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }
}

/// app 端 `uitestLanguageOverride` 取的是第一個命中的參數，這裡用同一條規則算出實際語言。
private func effectiveAppLanguage(_ args: [String]) -> String {
    let prefix = "--uitest-language="
    return args.first { $0.hasPrefix(prefix) }
        .map { String($0.dropFirst(prefix.count)) } ?? "zh-Hant"
}

/// 固定 POSIX ＋ 西曆，跟 app 端 `DayDate(isoString:)` 的解析對齊，不受裝置語系影響。
private func uitestTodayArgumentValue(now: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: now)
}
