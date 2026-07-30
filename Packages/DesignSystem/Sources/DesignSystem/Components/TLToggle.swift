import SwiftUI

/// 自訂開關樣式（設定列用）。46×28 capsule、旋鈕 22pt、padding 3。
///  - 開：`accent` 底、旋鈕 `bg`
///  - 關：`neutral-300` 底、旋鈕 `neutral-100`
///
/// 做成 `ToggleStyle`（而非自繪 Button）：底層仍是 `Toggle`，
/// 保留 switch 無障礙語意（VoiceOver 讀開/關、XCUITest 認得 `.switches` 且 value 為 "1"/"0"），
/// 只換外觀——不用系統綠。
public struct TLSwitchToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 0)
            knob(isOn: configuration.isOn)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.18)) { configuration.isOn.toggle() }
                }
        }
        .contentShape(Rectangle())
    }

    private func knob(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? TLColor.accent : TLColor.neutral300)
            .frame(width: TLSize.switchW, height: TLSize.switchH)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(isOn ? TLColor.bg : TLColor.neutral100)
                    .padding(3)
            }
    }
}

public extension ToggleStyle where Self == TLSwitchToggleStyle {
    /// `Toggle(...).toggleStyle(.tlSwitch)`
    static var tlSwitch: TLSwitchToggleStyle { .init() }
}
