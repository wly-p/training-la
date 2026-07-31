import DesignSystem
import SharedKernel
import SwiftUI

/// 級距偏好的 drill-in 編輯頁（重量／休息時間共用）。
///
/// 設計稿還沒畫這層，先照 `SettingsSelectionView` 的骨架（返回鈕＋`PageHeader`＋`TLGroup`）自建，
/// 內容用既有的 `ValuePicker` 滾輪選常用值，另外附一個輸入框給滾輪清單裡沒有的值
/// （例：一個卡扣 0.17kg）。等 UI 設計出來再改這一層，行為與持久化不受影響。
struct StepPreferenceView: View {
    let title: Text
    /// 滾輪的可選值。
    let options: [Double]
    /// 合法範圍；輸入框超出就不套用並顯示提示。
    let range: ClosedRange<Double>
    /// 值的單位標籤（"kg"／"秒"）。
    let unitLabel: String
    /// 小數位數：重量要小數（0.17），秒數是整數。
    let allowsDecimal: Bool
    let current: Double
    let onSelect: (Double) -> Void
    let onBack: () -> Void

    @State private var value: Double
    @State private var customText: String
    @State private var showsRangeHint = false

    init(
        title: Text,
        options: [Double],
        range: ClosedRange<Double>,
        unitLabel: String,
        allowsDecimal: Bool,
        current: Double,
        onSelect: @escaping (Double) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.title = title
        self.options = options
        self.range = range
        self.unitLabel = unitLabel
        self.allowsDecimal = allowsDecimal
        self.current = current
        self.onSelect = onSelect
        self.onBack = onBack
        // 目前值不在滾輪清單裡（使用者自訂過）→ 滾輪落在最接近的一格，輸入框顯示真正的值。
        _value = State(initialValue: options.contains(current) ? current : (options.first ?? current))
        _customText = State(initialValue: Weight.formatted(current))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backBar
                PageHeader(title)
                VStack(alignment: .leading, spacing: TLSpace.gapL) {
                    ValuePicker(
                        value: $value,
                        values: options,
                        kicker: unitLabel,
                        format: { "\(Weight.formatted($0)) \(unitLabel)" }
                    )
                    .onChange(of: value) { _, new in
                        customText = Weight.formatted(new)
                        showsRangeHint = false
                        onSelect(new)
                    }
                    customField
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.section)
            }
            .padding(.bottom, 40)
        }
        .background(TLColor.bg.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var backBar: some View {
        HStack {
            CircleIconButton(systemImage: "chevron.left", filled: false) { onBack() }
                .accessibilityLabel(localText("settings.back"))
            Spacer()
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.top, 8)
    }

    /// 滾輪清單以外的值（例：一個卡扣 0.17kg）。
    private var customField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TLGroup {
                HStack {
                    localText("settings.step.custom")
                        .font(TLFont.zh(TLFont.rowTitle))
                        .foregroundStyle(TLColor.text)
                    Spacer()
                    TextField("", text: $customText)
                        .font(TLFont.display(17))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 88)
                        #if os(iOS)
                        .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                        #endif
                        .onSubmit(applyCustom)
                        .accessibilityIdentifier("customStepField")
                    Text(verbatim: unitLabel)
                        .font(TLFont.zh(TLFont.rowSub))
                        .foregroundStyle(TLColor.neutral500)
                }
                .padding(.horizontal, TLSpace.rowInset)
                .frame(minHeight: TLSize.row)
            }
            hint
        }
        // 鍵盤收起（切走焦點）時也要套用，不能只靠 onSubmit——數字鍵盤沒有 return 鍵。
        .onChange(of: customText) { _, _ in applyCustom() }
    }

    @ViewBuilder
    private var hint: some View {
        let text = showsRangeHint
            ? String(
                format: String(localized: "settings.step.range %@ %@", bundle: .module),
                Weight.formatted(range.lowerBound), Weight.formatted(range.upperBound)
            )
            : ""
        Text(verbatim: text)
            .font(TLFont.zh(TLFont.rowSub))
            .foregroundStyle(showsRangeHint ? TLColor.danger : TLColor.neutral500)
            .padding(.horizontal, TLSpace.rowInset)
            .opacity(showsRangeHint ? 1 : 0)
    }

    /// 空字串不算錯（使用者正在刪字），只有真的打了超出範圍的值才提示。
    private func applyCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showsRangeHint = false
            return
        }
        guard let parsed = Double(trimmed), range.contains(parsed) else {
            showsRangeHint = true
            return
        }
        showsRangeHint = false
        onSelect(allowsDecimal ? parsed : parsed.rounded())
    }
}
