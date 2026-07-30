import SwiftUI

/// 模板 5：分段控制。
/// 軌道：capsule、`neutral-200`、padding 4。
/// 選中項：`bg` 白底 capsule ＋ shadow-sm、weight 700。
/// 未選：weight 500、`neutral-600`。每項垂直 padding 10。
/// 切換時選中膠囊滑動過去（0.2s ease-out）。
public struct TLSegmentedControl<Value: Hashable>: View {
    public struct Option: Identifiable {
        public let value: Value
        public let label: Text
        public var id: Value { value }
        /// 定值標籤（kg/lb 等 verbatim，不本地化）。
        public init(_ value: Value, _ label: String) {
            self.value = value
            self.label = Text(verbatim: label)
        }
        /// 本地化標籤：呼叫端用 `localText(key)` 或 `Text(key)` 建，才能對到 bundle、切語言即時重繪。
        public init(_ value: Value, _ label: Text) {
            self.value = value
            self.label = label
        }
    }

    @Binding private var selection: Value
    private let options: [Option]
    @Namespace private var pill

    public init(selection: Binding<Value>, options: [Option]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = option.value }
                } label: {
                    option.label
                        .font(TLFont.zh(TLFont.rowTitle, isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? TLColor.text : TLColor.neutral600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(TLColor.bg)
                                    .tlShadow(TLShadow.sm)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(TLColor.neutral200))
    }
}
