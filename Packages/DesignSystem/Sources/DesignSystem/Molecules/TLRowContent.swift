import SwiftUI

/// L2 分子。列的**內容排版**：左件 ＋ 主副標 ＋ 右件 ＋ 指向記號。
///
/// 規格：`design-system/molecules/TLRowContent/TLRowContent.spec.md`
///
/// **不含列的外框** —— 沒有左右內距、沒有最小高度、不可點。那些是 `TLListRow` 的事。
///
/// 為什麼要分開：卡片式的版面（例如長期課表的「進行中」卡）需要這個排版，
/// 但外框由卡片自己給 —— 卡片有自己的 padding，而且只有上半可點。
/// 兩者綁在一起的話，那種版面只能手工重畫一份，然後就會漂。
public struct TLRowContent<Leading: View, Detail: View, Trailing: View>: View {
    private let leading: Leading
    private let title: Text
    private let subtitle: Text?
    private let equipment: String?
    private let detail: Detail
    private let trailing: Trailing
    private let showChevron: Bool

    public init(
        title: Text,
        subtitle: Text? = nil,
        equipment: String? = nil,
        showChevron: Bool = false,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder detail: () -> Detail = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.equipment = equipment
        self.showChevron = showChevron
        self.leading = leading()
        self.detail = detail()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: TLSpace.gapM) {
            leading
            VStack(alignment: .leading, spacing: TLSpace.titleSubGap) {
                let styledTitle = title
                    .font(TLFont.zh(TLFont.rowTitle))
                    .foregroundColor(TLColor.text)
                if let equipment {
                    TLTitleWithTag(title: styledTitle, equipment: equipment)
                } else {
                    styledTitle
                        .lineLimit(1)
                        .truncationMode(.tail)                  // 列表列一行截斷加 …
                }
                if let subtitle {
                    subtitle
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // 細節行與標題共用同一條左緣——器材不再需要自己的欄，對齊問題自然消失（19a）。
                detail
            }
            Spacer(minLength: TLSpace.gapS)
            trailing
            if showChevron { TLChevron() }
        }
    }

    /// 這一列的最小高度。`TLListRow` 用它決定外框，卡片式版面通常不需要。
    public var preferredMinHeight: CGFloat {
        if Detail.self != EmptyView.self { return TLSize.rowWithDetail }
        return subtitle == nil ? TLSize.row : TLSize.rowWithSub
    }
}
