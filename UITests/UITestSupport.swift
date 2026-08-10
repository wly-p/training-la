import Foundation

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
func uitestLaunchArguments(_ extra: [String] = []) -> [String] {
    ["--uitest-inmemory", "--uitest-today=\(uitestTodayArgumentValue())"] + extra
}

/// 固定 POSIX ＋ 西曆，跟 app 端 `DayDate(isoString:)` 的解析對齊，不受裝置語系影響。
private func uitestTodayArgumentValue(now: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: now)
}
