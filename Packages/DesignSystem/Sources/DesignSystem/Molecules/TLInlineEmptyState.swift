import SwiftUI

/// L2 分子。清單裡的空狀態：一句主文 ＋ 一句說明，置中。
///
/// 規格：`design-system/molecules/TLInlineEmptyState/TLInlineEmptyState.spec.md`
///
/// 跟 `TLEmptyState` 的差別是**有沒有自己的容器**：
///   - 這個是**內嵌**的，直接放在清單原本的位置，沒有底色、沒有圖示、沒有按鈕
///   - `TLEmptyState` 是一張**卡**（圓角容器 ＋ 圖示圓 ＋ 可選按鈕），用在整頁皆空時
///
/// 文字吃 `Text`：呼叫端用各 package 的 `localText(key)` 建好再傳。
public struct TLInlineEmptyState: View {
    private let title: Text
    private let hint: Text?

    public init(title: Text, hint: Text? = nil) {
        self.title = title
        self.hint = hint
    }

    public var body: some View {
        VStack(spacing: TLSpace.emptyStateGap) {
            title
                .font(TLFont.zh(TLFont.emptyTitle, .bold))
                .foregroundStyle(TLColor.text)
            if let hint {
                hint
                    .font(TLFont.zh(TLFont.caption, .regular))
                    .foregroundStyle(TLColor.neutral600)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TLSpace.emptyStatePadV)
    }
}
