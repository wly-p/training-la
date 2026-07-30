import CoreText
import Foundation

/// Caprasimo（打包進 DesignSystem bundle 的 OFL 字體）的 runtime 註冊。
///
/// 為什麼要 runtime 註冊：App 的 Info.plist `UIAppFonts` 只掃描 main bundle，
/// 掃不到 SPM package 的資源。所以由本 module 用 CoreText 把字體登記進 process。
///
/// 觸發時機：`TLFont.display(_:)` 第一次被呼叫時自動註冊（`registerIfNeeded`），
/// 因此頁面只要用 token 取字體即可，不需要在 App 啟動流程手動掛勾。
/// 若想更早（例如啟動時預熱），可主動呼叫 `DesignSystemFonts.register()`。
public enum DesignSystemFonts {

    // 全程只跑一次；Swift 的 static let 保證執行緒安全的一次性初始化。
    private static let registerOnce: Void = {
        guard let url = Bundle.module.url(forResource: "Caprasimo-Regular", withExtension: "ttf") else {
            assertionFailure("DesignSystem: 找不到 Caprasimo-Regular.ttf（bundle 資源遺失）")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            // 已註冊過會回 false（例如 preview 重載），非致命 → 忽略。
            // 其他錯誤在 debug 期用 assert 提早發現。
            #if DEBUG
            if let error = error?.takeUnretainedValue() {
                let code = CFErrorGetCode(error)
                // kCTFontManagerErrorAlreadyRegistered = 105
                if code != 105 {
                    assertionFailure("DesignSystem: Caprasimo 註冊失敗（code \(code)）")
                }
            }
            #endif
        }
    }()

    /// 確保 Caprasimo 已註冊（冪等）。由 `TLFont.display` 自動呼叫。
    public static func registerIfNeeded() {
        _ = registerOnce
    }

    /// 對外的明確註冊入口（可在 App 啟動時預熱，非必要）。
    public static func register() {
        registerIfNeeded()
    }
}
