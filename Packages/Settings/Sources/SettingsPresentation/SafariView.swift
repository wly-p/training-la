#if os(iOS)
import SafariServices
import SwiftUI

/// `SFSafariViewController` 的 SwiftUI 包裝，給設定頁的隱私政策入口用。
///
/// 為什麼是 Safari 而不是 `WKWebView`：政策頁是**線上單一來源**（App 不打包副本、不做離線
/// fallback），只需要開 http(s)，那 Safari 的工具列、載入指示與錯誤頁就都是現成的，
/// 不必自己重做一套。載入失敗時使用者看到的是 Safari 原生錯誤頁——這是刻意接受的結果。
///
/// `url` 每次開啟由呼叫端依當下 app 語言重算（fragment 決定頁面顯示中英），
/// 所以這裡不需要 `updateUIViewController` 做任何事：換語言＝重新 present 一個新的。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif
