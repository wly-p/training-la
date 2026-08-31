import SwiftUI

/// L2 分子。內容卡：圓角容器 ＋ 底色 ＋ 內距。
///
/// 規格：`design-system/molecules/TLCard/TLCard.spec.md`
///
/// 跟 `TLGroup` 的差別：那個是**列的容器**（負責列與列之間的分隔線、切掉溢出）；
/// 這個是**內容的容器**，裡面放什麼都可以，沒有分隔線。
/// 判準：裡面是一串列就用 `TLGroup`，是一塊內容就用這個。
///
/// 底色是 prop 而不是固定值：全 app 有兩階卡底（`neutral-100` 與 `neutral-300`）
/// 疊在同一個頁面底上。⚠ 第二階目前沒有語意名字，見規格第 6 節。
public struct TLCard<Content: View>: View {
    /// 內距。`rowInset` 是常態；空狀態那種「一大塊留白」用 `roomy`。
    public enum Padding {
        case standard
        case roomy

        var horizontal: CGFloat { self == .standard ? TLSpace.rowInset : TLSpace.page }
        var vertical: CGFloat { self == .standard ? TLSpace.rowInset : TLSpace.section }
    }

    private let fill: Color
    private let border: Color?
    private let padding: Padding
    private let content: Content

    public init(
        fill: Color = TLColor.surfaceRaised,
        border: Color? = nil,
        padding: Padding = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.border = border
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, padding.horizontal)
            .padding(.vertical, padding.vertical)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous)
                        .strokeBorder(border, lineWidth: TLSize.hairlineThick)
                }
            }
    }
}
