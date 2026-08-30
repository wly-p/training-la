import SwiftUI

// 模板 3：列表列。放進 `TLGroup` 容器（負責圓角 28 + neutral-100 底 + 列間分隔線）。
//
// 三型（同一列，不同填法）：
//   1. 圖示／圓章 ＋ 主副標 ＋ 右值 ＋ chevron
//   2. 純文字 ＋ 右值
//   3. 可勾選（22pt 赭紅圓形勾）
//
// 標題下方有兩種第二行，擇一：
//   - `subtitle`（純文字）＝「組成摘要」，例如範本列出它含哪些動作
//   - `detail`（ViewBuilder）＝「細節行」，放得下 pill 這類非文字元素（18b/19a）
//
// 狀態一律放右側 meta。


public struct TLListRow<Leading: View, Detail: View, Trailing: View>: View {
    private let leading: Leading
    private let title: Text
    private let subtitle: Text?
    /// 動作名右側的器材小標；nil＝不用這個排法。
    ///
    /// ⚠️ 動作庫（`18b`）與範本（`19a`）已經**不走這條** —— 器材在那兩處是尾欄／細節行。
    /// 這裡留給訓練中、預覽 sheet、歷史詳情、能力值那四個「名稱後面跟一顆 pill」的位置。
    private let equipment: String?
    private let detail: Detail
    private let trailing: Trailing
    private let showChevron: Bool
    private let onTap: (() -> Void)?

    public init(
        title: Text,
        subtitle: Text? = nil,
        equipment: String? = nil,
        showChevron: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder detail: () -> Detail = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.equipment = equipment
        self.showChevron = showChevron
        self.onTap = onTap
        self.leading = leading()
        self.detail = detail()
        self.trailing = trailing()
    }

    /// 有細節行 68 > 有副標 62 > 單行 56。細節行放的是 pill，比一行文字高。
    private var minHeight: CGFloat {
        if Detail.self != EmptyView.self { return TLSize.rowWithDetail }
        return subtitle == nil ? TLSize.row : TLSize.rowWithSub
    }

    private var content: some View {
        HStack(spacing: TLSpace.gapM) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                let styledTitle = title
                    .font(TLFont.zh(TLFont.rowTitle))          // 15pt weight 500
                    .foregroundColor(TLColor.text)
                if let equipment {
                    TLExerciseNameWithEquipment(title: styledTitle, equipment: equipment)
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
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: minHeight)
        .contentShape(Rectangle())
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(TLRowPressStyle())
        } else {
            content
        }
    }
}

/// 列的按下回饋：底色 → text @6%（無縮放）。
struct TLRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? TLColor.text.opacity(0.06) : Color.clear)
    }
}
