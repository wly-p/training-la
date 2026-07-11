/// App icon 切換的介面。抽成 protocol 讓 ViewModel 可注入 mock 測試（免模擬器）。
/// `@MainActor`：真正的實作要碰 `UIApplication`（本身就是 MainActor-isolated），
/// 這個 protocol 的唯一使用者 `SettingsViewModel` 也已經是 `@MainActor`，同一個 actor 不需要再處理跨 actor 的 Sendable。
@MainActor
public protocol IconSwitching {
    /// 目前生效的 alternate icon 名稱；nil＝預設 app icon。
    var currentIconName: String? { get }
    func setIcon(_ name: String?) async throws
}

#if canImport(UIKit)
import UIKit

/// `UIApplication.setAlternateIconName` 的實作。只在 iOS 有效；
/// 這個 package 也要能在 macOS 上跑 `swift test`，所以包在 `canImport(UIKit)` 裡。
public struct UIApplicationIconSwitcher: IconSwitching {
    public init() {}

    public var currentIconName: String? {
        UIApplication.shared.alternateIconName
    }

    public func setIcon(_ name: String?) async throws {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(name) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
#endif
