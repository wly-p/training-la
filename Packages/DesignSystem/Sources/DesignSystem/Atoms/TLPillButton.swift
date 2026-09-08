import SwiftUI

/// L1 原子。填色的小膠囊鈕。
///
/// 規格：`design-system/atoms/TLPillButton/TLPillButton.spec.md`
///
/// 跟 `.tlSecondarySmall` 的差別：那個是**線框**（次要動作），這個是**填色**
/// （坐在有色底上的動作，例如休息畫面的預設秒數、輸入色帶的快捷鍵）。
/// 判準：它坐在什麼上面？坐在頁面底上用線框，坐在色塊上用這個。
public struct TLPillButton: View {
    /// 寬度行為。`hug` 跟著內容，`fill` 撐滿可用寬度。
    ///
    /// ⚠ 兩者目前的上下內距差 2px（8／10）。同一顆鈕的兩種寬度該不該有不同的高度，
    /// 是膠囊幾何那組待決問題的一部分——先如實保留兩個值，不自己收。
    public enum Width { case hug, fill }

    private let title: Text
    private let tint: Color
    private let width: Width
    private let action: () -> Void

    public init(
        _ title: Text,
        tint: Color = TLColor.accent700,
        width: Width = .hug,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tint = tint
        self.width = width
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            title
                .font(TLFont.zh(TLFont.buttonLabelSmall, .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, TLSpace.pillPadH)
                .padding(.vertical, width == .fill ? TLSpace.pillPadVWide : TLSpace.pillPadV)
                .frame(maxWidth: width == .fill ? .infinity : nil)
                .background(TLColor.bg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
