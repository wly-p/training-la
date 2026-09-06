import SwiftUI

/// 開關型設定列。底層是 `Toggle` + `TLSwitchToggleStyle`，保留 switch 無障礙語意。
///
/// 說明文字有兩種放法，都**不計入 switch 的無障礙標籤**（標籤只用標題）：
///   - `hint`：標題後方同一行的小灰字，短詞用（如「含震動」）
///   - `subtitle`：標題下方第二行，整句用（如「App 不在前景時以系統通知提醒」）。列高改吃 62。
///
/// 說明文字固定屬於某一列，不要放在群組下方——那會產生「這段在解釋整組還是最後一列」的歧義。
public struct TLSettingsToggleRow: View {
    private let title: Text
    private let hint: Text?
    private let subtitle: Text?
    @Binding private var isOn: Bool

    public init(_ title: Text, hint: Text? = nil, subtitle: Text? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.hint = hint
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: TLSpace.titleSubGap) {
                HStack(alignment: .firstTextBaseline, spacing: TLSpace.titleHintGap) {
                    title
                        .font(TLFont.zh(TLFont.rowTitle))
                        .foregroundStyle(TLColor.text)
                    if let hint {
                        hint
                            .font(TLFont.zh(TLFont.rowSub, .regular))
                            .foregroundStyle(TLColor.neutral500)
                    }
                }
                if let subtitle {
                    subtitle
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.tlSwitch)
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: subtitle == nil ? TLSize.row : TLSize.rowWithSub)
    }
}
