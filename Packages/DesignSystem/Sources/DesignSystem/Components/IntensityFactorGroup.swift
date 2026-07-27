import SwiftUI

/// 強度基準群組（14b，設計稿 03-schedule.md B 節）：循環／長期編輯頁共用的「這幾週輕一點」表達方式。
/// 倍率放在計畫上（這個元件綁一個 `Double`），不是每一格——格子的覆寫值由呼叫端另外處理
/// （週期清單那一列的膠囊，不歸這個元件管）。
///
/// 純顯示元件，不做 i18n：字串／Text 由呼叫端（各 package 的 String Catalog）決定，這裡只排版。
public struct IntensityFactorGroup: View {
    /// 「套用後」試算的一行：例如「臥推 組3」「80% × 85%」「67.5 kg」。
    public struct PreviewLine: Identifiable {
        public let id = UUID()
        public let label: Text
        public let expression: Text
        public let result: Text
        public init(label: Text, expression: Text, result: Text) {
            self.label = label
            self.expression = expression
            self.result = result
        }
    }

    @Binding private var factor: Double
    private let customLabel: String
    private let previewLines: [PreviewLine]
    private let footnote: Text?

    @State private var showCustom: Bool

    private static let presets: [Double] = [0.75, 0.85, 1.0]
    private static let customRange: [Double] = {
        // 0.5–1.2, step 0.05；用整數運算避免浮點誤差堆積。
        stride(from: 50, through: 120, by: 5).map { Double($0) / 100 }
    }()

    public init(
        factor: Binding<Double>,
        customLabel: String,
        previewLines: [PreviewLine] = [],
        footnote: Text? = nil
    ) {
        self._factor = factor
        self.customLabel = customLabel
        self.previewLines = previewLines
        self.footnote = footnote
        self._showCustom = State(initialValue: !Self.presets.contains(factor.wrappedValue))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            chipsRow
            if showCustom {
                ValuePicker(
                    value: $factor,
                    values: Self.customRange,
                    format: { String(format: "%.0f%%", $0 * 100) }
                )
            }
            if !previewLines.isEmpty {
                previewBox
            }
            if let footnote {
                footnote
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
            }
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private var chipsRow: some View {
        HStack(spacing: 8) {
            ForEach(Self.presets, id: \.self) { preset in
                SelectableChip(
                    String(format: "%.0f%%", preset * 100),
                    isSelected: !showCustom && factor == preset,
                    selectedFill: TLColor.accent, selectedText: TLColor.bg,
                    onTap: { showCustom = false; factor = preset }
                )
            }
            SelectableChip(
                customLabel, isSelected: showCustom,
                selectedFill: TLColor.accent, selectedText: TLColor.bg,
                onTap: { showCustom = true }
            )
        }
    }

    /// 「套用後」試算方塊：bg 底、圓角 20——巢在外層 neutral-100 容器裡分層。
    private var previewBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(previewLines) { line in
                HStack {
                    line.label
                        .font(TLFont.zh(TLFont.rowSub, .medium))
                        .foregroundStyle(TLColor.neutral700)
                    Spacer()
                    line.expression
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                    Text(verbatim: "→")
                        .foregroundStyle(TLColor.neutral400)
                    line.result
                        .font(TLFont.zh(TLFont.rowTitle, .semibold))
                        .foregroundStyle(TLColor.text)
                }
            }
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// 週期清單格子尾端的強度覆寫膠囊（14b）：未覆寫＝線框「基準」，已覆寫＝accent 實心「×75%」。
/// 點擊開 `ValuePicker`（呼叫端接手示範層，這裡只負責膠囊外觀＋點擊回呼）。
public struct IntensityOverridePill: View {
    private let factor: Double?
    private let baselineLabel: String
    private let onTap: () -> Void

    public init(factor: Double?, baselineLabel: String, onTap: @escaping () -> Void) {
        self.factor = factor
        self.baselineLabel = baselineLabel
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Group {
                if let factor {
                    Text(verbatim: String(format: "×%.0f%%", factor * 100))
                        .foregroundStyle(TLColor.bg)
                } else {
                    Text(verbatim: baselineLabel)
                        .foregroundStyle(TLColor.neutral600)
                }
            }
            .font(TLFont.zh(11.5, .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                if factor != nil {
                    Capsule().fill(TLColor.accent)
                } else {
                    Capsule().strokeBorder(TLColor.neutral400, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
