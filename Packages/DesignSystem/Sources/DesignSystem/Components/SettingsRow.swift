import SwiftUI

/// 模板 4：設定列。同容器規則（放進 `TLGroup`），列高 56、無圓章。
///
/// 右側三型（用 trailing ViewBuilder 塞）：
///   - 值＋chevron：`trailing: { SettingsValue("跟隨系統") }` 且 `showChevron: true`
///   - 自訂開關：`trailing: { TLToggle(isOn: $x) }`
///   - 分段控制：`trailing: { TLSegmentedControl(...) }`（較寬時可整列改用）
///
/// 破壞性列：`SettingsRow("刪除所有資料", role: .destructive) { … }`
/// → `danger-700` 文字＋垃圾桶圖示。
public struct SettingsRow<Trailing: View>: View {
    public enum Role { case normal, destructive }

    private let title: String
    private let systemImage: String?
    private let role: Role
    private let showChevron: Bool
    private let onTap: (() -> Void)?
    private let trailing: Trailing

    public init(
        _ title: String,
        systemImage: String? = nil,
        role: Role = .normal,
        showChevron: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.showChevron = showChevron
        self.onTap = onTap
        self.trailing = trailing()
    }

    private var titleColor: Color { role == .destructive ? TLColor.danger700 : TLColor.text }

    private var content: some View {
        HStack(spacing: TLSpace.gapM) {
            if role == .destructive {
                Image(systemName: systemImage ?? "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TLColor.danger700)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TLColor.neutral600)
            }
            Text(title)
                .font(TLFont.zh(TLFont.rowTitle))
                .foregroundStyle(titleColor)
            Spacer(minLength: TLSpace.gapS)
            trailing
            if showChevron { Chevron() }
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.row)
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

public extension SettingsRow where Trailing == EmptyView {
    /// 無右側自訂內容的設定列（值＋chevron 型：把值放進 `SettingsValue` 當 trailing，
    /// 或用這個 + `SettingsValue` 皆可；本 init 給只有標題／chevron 的最單純情境）。
    init(
        _ title: String,
        systemImage: String? = nil,
        role: Role = .normal,
        showChevron: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.init(title, systemImage: systemImage, role: role,
                  showChevron: showChevron, onTap: onTap) { EmptyView() }
    }
}

/// 設定列右側的值＋chevron 用的值文字（15pt、neutral-500）。
public struct SettingsValue: View {
    private let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(TLFont.zh(TLFont.rowTitle))
            .foregroundStyle(TLColor.neutral500)
    }
}
