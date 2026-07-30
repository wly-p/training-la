import SwiftUI

/// 群組容器：圓角 28 + `neutral-100` 底 + 列間分隔線（頭尾不畫線）。
/// 取代原生 List／Form 的底框。`ListRow` 與 `SettingsRow` 都放進這裡。
public struct TLGroup<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        DividedVStack {
            content
        }
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }
}
