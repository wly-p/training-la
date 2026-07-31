import SwiftUI

/// 左滑露出單一動作的列（設計稿 8b：循環左滑露「停用」，88pt 寬、`neutral-400` 底、非紅）。
/// 用在 DesignSystem 自訂容器（`TLGroup`）內的列——原生 `.swipeActions` 只能用在 `List`，故自建。
///
/// 內容自帶不透明底（關閉時完全蓋住底下的動作鈕）。水平為主的拖曳才觸發，避免搶走垂直捲動。
public struct SwipeToRevealRow<Content: View>: View {
    private let actionLabel: Text
    private let actionSystemImage: String
    private let actionTint: Color
    private let actionForeground: Color
    private let onAction: () -> Void
    private let content: Content

    @State private var offset: CGFloat = 0
    @State private var committed: CGFloat = 0

    private let actionWidth: CGFloat = 88

    public init(
        actionLabel: Text,
        actionSystemImage: String,
        actionTint: Color = TLColor.neutral400,
        actionForeground: Color = TLColor.bg,
        onAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.actionLabel = actionLabel
        self.actionSystemImage = actionSystemImage
        self.actionTint = actionTint
        self.actionForeground = actionForeground
        self.onAction = onAction
        self.content = content()
    }

    public var body: some View {
        // 動作鈕放進 .background 而不是 ZStack 的一員：ZStack 的高度取所有子層的最大值，
        // 而動作鈕若宣告 maxHeight: .infinity 就會貪心撐高，把 TLGroup(DividedVStack) 裡的
        // 上下列推開、分隔線也跟著跑掉。改成 background 之後高度純由 content 決定，
        // 動作鈕再撐滿那個高度（8b 版面錯位的成因）。
        content
            .background(TLColor.neutral100)   // 不透明：關閉時完全蓋住底下的動作鈕
            .offset(x: offset)
            .background(alignment: .trailing) { actionButton }
            .clipped()
            // 普通 .gesture（非 simultaneous/highPriority）：垂直捲動歸 ScrollView、
            // 水平拖曳歸這裡（vertical ScrollView 不搶水平）、點擊歸內層 NavigationLink。
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        offset = min(0, max(-actionWidth, committed + value.translation.width))
                    }
                    // 這裡刻意不做方向判斷。onChanged 有方向 guard、onEnded 也有的話，
                    // 斜向或「先水平後轉垂直」的手勢會讓 onChanged 已經移動了 offset、
                    // onEnded 卻整個跳過 —— 列就停在半開、committed 也沒更新，
                    // 下一次拖曳還會從錯的起點算（8b 卡住的成因）。
                    // 只要放開手，一律收斂到「開到底或關回去」。
                    .onEnded { _ in
                        let open = offset < -actionWidth / 2
                        let target: CGFloat = open ? -actionWidth : 0
                        withAnimation(.easeOut(duration: 0.2)) { offset = target }
                        committed = target
                    }
            )
    }

    /// 露出於右側的動作鈕。高度撐滿 content（由 background 決定），寬度固定。
    private var actionButton: some View {
        Button {
            close()
            onAction()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: actionSystemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)   // 裝飾圖示：讓 Button 的 a11y label 只剩文字
                actionLabel
                    .font(TLFont.zh(TLFont.rowSub, .semibold))
            }
            .foregroundStyle(actionForeground)
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
            .background(actionTint)
        }
        .buttonStyle(.plain)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
        committed = 0
    }
}
