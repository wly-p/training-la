#if os(iOS)
import SwiftUI
import UIKit

/// `UIActivityViewController` 的 SwiftUI 包裝，給匯出資料用——存到「檔案」、AirDrop、
/// 傳給自己都走系統原生的分享面板，不用自己刻一套。
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad 用 popover 呈現，需要錨點否則可能崩潰或顯示不出來；iPhone 上這段是 no-op。
        if let popover = controller.popoverPresentationController {
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .windows.first { $0.isKeyWindow }
            popover.sourceView = keyWindow?.rootViewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
