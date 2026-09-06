#if os(iOS)
import SwiftUI
import UIKit

/// `UIActivityViewController` 的 SwiftUI 包裝，給匯出資料用——存到「檔案」、AirDrop、
/// 傳給自己都走系統原生的分享面板，不用自己刻一套。
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
