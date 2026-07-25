import SwiftUI

/// 自訂開關（設定列用）。46×28 capsule、旋鈕 22pt、padding 3。
///  - 開：`accent` 底、旋鈕 `bg`
///  - 關：`neutral-300` 底、旋鈕 `neutral-100`
///
/// 不用系統 `Toggle` 的預設樣式 —— 系統綠會讓整頁瞬間變回原生。
public struct TLToggle: View {
    @Binding private var isOn: Bool
    public init(isOn: Binding<Bool>) { self._isOn = isOn }

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(isOn ? TLColor.accent : TLColor.neutral300)
                .frame(width: TLSize.switchW, height: TLSize.switchH)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? TLColor.bg : TLColor.neutral100)
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? Text("開") : Text("關"))
    }
}
