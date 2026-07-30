import SwiftUI

// 模板 3：列表列。放進 `TLGroup` 容器（負責圓角 28 + neutral-100 底 + 列間分隔線）。
//
// 三型（同一列，不同填法）：
//   1. 圖示／圓章 ＋ 主副標 ＋ 右值 ＋ chevron
//   2. 純文字 ＋ 右值
//   3. 可勾選（22pt 赭紅圓形勾）
//
// 副標永遠是「組成摘要」；狀態一律放右側 meta。

/// 左側 36pt 圓章。內容可為肌群字（動作）、數字（範本）、圖示（循環／長期）。
public struct CircleBadge<Content: View>: View {
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

public extension CircleBadge where Content == Text {
    /// 肌群字圓章（動作用）：sage-200 底、sage-800 字。
    init(muscle: String) {
        self.init(fill: TLColor.sage200) {
            Text(muscle)
                .font(TLFont.zh(12, .semibold))
                .foregroundStyle(TLColor.sage800)
        }
    }
    /// 數字圓章（範本含幾個動作）：sage-200 底、sage-800 字（Caprasimo）。
    init(count: Int) {
        self.init(fill: TLColor.sage200) {
            Text("\(count)")
                .font(TLFont.display(16))
                .foregroundStyle(TLColor.sage800)
        }
    }
}

public extension CircleBadge where Content == AnyView {
    /// 圖示圓章（循環＝循環箭頭、長期＝長條圖）。`fill` 底、`tint` 圖示色。
    init(icon systemName: String, fill: Color, tint: Color) {
        self.init(fill: fill) {
            AnyView(
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            )
        }
    }
}

/// 22pt 赭紅圓形勾（可勾選列）。
public struct CheckBadge: View {
    private let isChecked: Bool
    public init(isChecked: Bool) { self.isChecked = isChecked }
    public var body: some View {
        ZStack {
            Circle()
                .fill(isChecked ? TLColor.accent : Color.clear)
                .overlay(Circle().strokeBorder(isChecked ? Color.clear : TLColor.neutral400, lineWidth: 1.5))
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TLColor.bg)
            }
        }
        .frame(width: 22, height: 22)
    }
}

/// 右側 chevron（16pt、neutral-500）。
public struct Chevron: View {
    public init() {}
    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(TLColor.neutral500)
    }
}

/// 右側數值 meta：數字用 Caprasimo，可選單位（15pt、neutral-700）。
/// 例：`RowValue("62.5", unit: "kg")`、`RowValue("3 × 8")`。
public struct RowValue: View {
    private let value: String
    private let unit: String?
    public init(_ value: String, unit: String? = nil) {
        self.value = value
        self.unit = unit
    }
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(TLFont.display(16))
                .foregroundStyle(TLColor.text)
            if let unit {
                Text(unit)
                    .font(TLFont.zh(TLFont.rowTitle))
                    .foregroundStyle(TLColor.neutral700)
            }
        }
    }
}

public struct ListRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let title: Text
    private let subtitle: Text?
    private let trailing: Trailing
    private let showChevron: Bool
    private let onTap: (() -> Void)?

    public init(
        title: Text,
        subtitle: Text? = nil,
        showChevron: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showChevron = showChevron
        self.onTap = onTap
        self.leading = leading()
        self.trailing = trailing()
    }

    private var content: some View {
        HStack(spacing: TLSpace.gapM) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(TLFont.zh(TLFont.rowTitle))          // 15pt weight 500
                    .foregroundStyle(TLColor.text)
                    .lineLimit(1)
                    .truncationMode(.tail)                      // 列表列一行截斷加 …
                if let subtitle {
                    subtitle
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: TLSpace.gapS)
            trailing
            if showChevron { Chevron() }
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: subtitle == nil ? TLSize.row : TLSize.rowWithSub)
        .contentShape(Rectangle())
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(RowPressStyle())
        } else {
            content
        }
    }
}

/// 列的按下回饋：底色 → text @6%（無縮放）。
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? TLColor.text.opacity(0.06) : Color.clear)
    }
}
