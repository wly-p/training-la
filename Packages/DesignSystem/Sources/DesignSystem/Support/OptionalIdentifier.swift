import SwiftUI

/// 有值才套 `accessibilityIdentifier` 的 modifier。
///
/// `accessibilityIdentifier` 是**測試定位**用的，不是無障礙工程
/// （見 `ARCHITECTURE.md` 的 UI test 定位慣例）。
///
/// 這裡是 public 而非 internal，因為 `DesignControls` 的控制項也要用。
public struct OptionalIdentifier: ViewModifier {

    public let id: String?

    public init(id: String?) { self.id = id }
    public func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

public extension View {
    /// `id` 為 nil 時不套 —— 呼叫端不必自己寫 if。
    func optionalIdentifier(_ id: String?) -> some View {
        modifier(OptionalIdentifier(id: id))
    }
}
