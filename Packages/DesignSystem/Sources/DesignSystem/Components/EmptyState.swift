import SwiftUI

/// 模板 10：空狀態。
/// 52pt 圓（`neutral-200`）內含圖示 → 標題 16pt weight 700 → 說明 12.5pt `neutral-600` → 主要按鈕。
/// 整體置中，容器圓角 28、`neutral-100` 底、padding 26×22。
public struct EmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    /// 行動鈕的 accessibilityIdentifier。按鈕文字會跟著語言換，UI test 要靠 id 定位。
    private let actionIdentifier: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        actionIdentifier: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(TLColor.neutral200)
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(TLColor.neutral600)
            }
            .frame(width: 52, height: 52)

            Text(title)
                .font(TLFont.zh(16, .bold))
                .foregroundStyle(TLColor.text)

            Text(message)
                .font(TLFont.zh(12.5, .regular))
                .foregroundStyle(TLColor.neutral600)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.tlPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, 4)
                    .modifier(OptionalIdentifier(id: actionIdentifier))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, TLSpace.page)
        .padding(.vertical, 22)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }
}
