import SwiftUI

/// L2 分子。一個統計數字 ＋ 它的標籤。
///
/// 規格：`design-system/molecules/TLStat/TLStat.spec.md`
///
/// 標籤在**下面**不是上面：掃視時先看到數字，標籤只在需要確認「這是什麼」時才讀。
///
/// 數字的字級是 prop 而不是固定值 —— 訓練首頁的週統計用 `cardNumber`(26)、
/// 完成摘要的用 34。⚠ display 家族的尺度還沒收斂（第二批），
/// 所以 34 那一階目前還沒有角色名，由呼叫端傳。
public struct TLStat: View {
    private let value: Text
    private let label: Text
    private let numberFont: Font
    private let alignment: HorizontalAlignment

    public init(
        value: Text,
        label: Text,
        numberFont: Font = TLFont.display(TLFont.cardNumber),
        alignment: HorizontalAlignment = .leading
    ) {
        self.value = value
        self.label = label
        self.numberFont = numberFont
        self.alignment = alignment
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: TLSpace.titleSubGap) {
            value
                .font(numberFont)
                .foregroundStyle(TLColor.text)
            label
                .font(TLFont.zh(TLFont.rowSub))
                .foregroundStyle(TLColor.neutral600)
        }
    }
}
