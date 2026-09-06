#if canImport(UIKit)
import UIKit

/// 打開系統的「本 App 設定」頁——通知授權被拒絕後，只能從那裡重新開啟，
/// app 內部的開關無法直接授權。
enum SystemSettingsOpener {
    @MainActor
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
