import SwiftUI

/// 大數字輸入（handoff-15 G 節）：數字本身就是輸入框，不需要另一個入口。
/// 60pt Caprasimo ＋ 底部 2.5px accent 下劃線，點下去直接開 `decimalPad`。
///
/// 取代「垂直滾輪佔掉半個畫面只為輸入一個數字」的舊做法。滾輪適合微調，
/// 但從 20 調到 180 得滑很久 —— 那種情況直接打字最快。
///
/// 數字鍵盤沒有 return 鍵，所以一定要有鍵盤工具列的「完成」，否則叫出鍵盤就收不掉。
public struct TLNumberField: View {
    @Binding private var value: Double
    private let unitLabel: String
    private let allowsDecimal: Bool
    private let doneLabel: Text

    /// 編輯中的文字。跟 `value` 分開存：邊打邊同步會讓「12.」「0.」這種中間狀態被吃掉。
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    public init(
        value: Binding<Double>,
        unitLabel: String,
        allowsDecimal: Bool = true,
        doneLabel: Text = Text(verbatim: "OK")
    ) {
        self._value = value
        self.unitLabel = unitLabel
        self.allowsDecimal = allowsDecimal
        self.doneLabel = doneLabel
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            TextField("", text: $text)
                .font(TLFont.display(60))
                .foregroundStyle(TLColor.text)
                .multilineTextAlignment(.center)
                .fixedSize()
                #if os(iOS)
                .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                #endif
                .focused($isFocused)
                .accessibilityIdentifier("abilityValueField")
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(TLColor.accent)
                        .frame(height: 2.5)
                        .offset(y: 6)
                }
            Text(verbatim: unitLabel)
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.neutral600)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear { text = Self.format(value) }
        // 外部改值（刻度尺拖曳、± 按鈕、套用建議）時同步顯示，但編輯中不覆蓋使用者正在打的字。
        .onChange(of: value) { _, new in
            guard !isFocused else { return }
            text = Self.format(new)
        }
        .onChange(of: text) { _, new in
            guard let parsed = Double(new.trimmingCharacters(in: .whitespaces)) else { return }
            value = parsed
        }
        // 失焦時把顯示正規化回來（"070" → "70"、空字串 → 原值）。
        .onChange(of: isFocused) { _, focused in
            guard !focused else { return }
            text = Self.format(value)
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button { isFocused = false } label: { doneLabel }
            }
        }
        #endif
    }

    /// 最多一位小數（handoff-15 A 節）：能力值不需要更細，而 69.66666666666666 是 bug。
    public static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }
}
