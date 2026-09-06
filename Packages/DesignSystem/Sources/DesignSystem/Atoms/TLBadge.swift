import SwiftUI

/// 左側 36pt 圓章。內容可為肌群字（動作）、數字（範本）、圖示（循環／長期）。
public struct TLBadge<Content: View>: View {
    private let fill: Color
    private let size: CGFloat
    private let content: Content

    public init(fill: Color, size: CGFloat = TLSize.badge, @ViewBuilder content: () -> Content) {
        self.fill = fill
        self.size = size
        self.content = content()
    }

    public var body: some View {
        ZStack {
            Circle().fill(fill)
            content
        }
        .frame(width: size, height: size)
    }
}

public extension TLBadge where Content == Text {
    /// 肌群字圓章（動作用）：sage-200 底、sage-800 字。
    init(muscle: String) {
        self.init(fill: TLColor.sage200) {
            Text(muscle)
                .font(TLFont.zh(TLFont.badgeText, .semibold))
                .foregroundStyle(TLColor.sage800)
        }
    }
    /// 數字圓章（例：這份範本含幾個動作）。數字用 Caprasimo。
    ///
    /// 顏色開成 prop 而不是寫死：同一個圓章在「這是什麼分類」與「這裡有幾個」
    /// 兩種語意下用不同色階，寫死的話第二種只能繞過這個 init 手工重建。
    init(count: Int, fill: Color = TLColor.sage200, tint: Color = TLColor.sage800) {
        self.init(fill: fill) {
            Text("\(count)")
                .font(TLFont.display(TLFont.rowNumber))
                .foregroundStyle(tint)
        }
    }
}

public extension TLBadge where Content == AnyView {
    /// 圖示圓章（循環＝循環箭頭、長期＝長條圖）。`fill` 底、`tint` 圖示色。
    init(icon systemName: String, fill: Color, tint: Color) {
        self.init(fill: fill) {
            AnyView(
                Image(systemName: systemName)
                    .font(.system(size: TLIcon.inline, weight: TLIcon.weight))
                    .foregroundStyle(tint)
            )
        }
    }
}
