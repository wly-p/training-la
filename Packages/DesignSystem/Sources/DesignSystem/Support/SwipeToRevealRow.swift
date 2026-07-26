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
        ZStack(alignment: .trailing) {
            // 底層動作鈕（露出於右側）
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

            // 上層內容（不透明底，關閉時蓋住動作鈕）
            content
                .background(TLColor.neutral100)
                .offset(x: offset)
                // 普通 .gesture（非 simultaneous/highPriority）：垂直捲動歸 ScrollView、
                // 水平拖曳歸這裡（vertical ScrollView 不搶水平）、點擊歸內層 NavigationLink。
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            offset = min(0, max(-actionWidth, committed + value.translation.width))
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) >= abs(value.translation.height) else { return }
                            let open = offset < -actionWidth / 2
                            withAnimation(.easeOut(duration: 0.2)) { offset = open ? -actionWidth : 0 }
                            committed = offset
                        }
                )
        }
        .clipped()
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
        committed = 0
    }
}
