import SwiftUI

/// L2 分子。內容卡：圓角容器 ＋ 底色 ＋ 內距。
///
/// 規格：`design-system/molecules/TLCard/TLCard.spec.md`
///
/// 跟 `TLGroup` 的差別：那個是**列的容器**（負責列與列之間的分隔線、切掉溢出）；
/// 這個是**內容的容器**，裡面放什麼都可以，沒有分隔線。
/// 判準：裡面是一串列就用 `TLGroup`，是一塊內容就用這個。
///
/// 底色是 prop 而不是固定值：全 app 有三階卡底（`neutral-100`／`neutral-300`／`accent-200`）
/// 疊在同一個頁面底上。⚠ 後兩階目前沒有語意名字，見規格第 6 節。
public struct TLCard<Content: View>: View {
    /// 圓角。**卡中的區塊要換小圓角** —— 兩層 `container` 疊在一起，
    /// 內圈看起來會是壞的。全 app 有 9 處這種巢狀區塊。
    public enum Radius {
        case container
        case inner

        var value: CGFloat { self == .container ? TLRadius.container : TLRadius.inner }
    }

    /// 內距。`standard` 是常態；`roomy` 給「一大塊留白」的說明卡；
    /// `page` 給整頁級的大卡（訓練首頁那張續練卡）。
    public enum Padding {
        case standard
        case roomy
        case page

        var horizontal: CGFloat {
            switch self {
            case .standard: TLSpace.rowInset
            case .roomy, .page: TLSpace.page
            }
        }

        var vertical: CGFloat {
            switch self {
            case .standard: TLSpace.rowInset
            case .roomy: TLSpace.section
            case .page: TLSpace.page
            }
        }
    }

    private let radius: Radius
    private let fill: Color
    private let border: Color?
    private let padding: Padding
    private let content: Content

    public init(
        radius: Radius = .container,
        fill: Color = TLColor.surfaceRaised,
        border: Color? = nil,
        padding: Padding = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.fill = fill
        self.border = border
        self.padding = padding
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius.value, style: .continuous)
    }

    public var body: some View {
        content
            .padding(.horizontal, padding.horizontal)
            .padding(.vertical, padding.vertical)
            .background(fill)
            .clipShape(shape)
            .overlay {
                if let border {
                    shape.strokeBorder(border, lineWidth: TLSize.hairlineThick)
                }
            }
    }
}
