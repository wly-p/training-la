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
    /// 每一段的 accessibilityIdentifier 前綴：第 n 段會拿到 `<prefix>.<value>`
    /// （例：`history.segment.byExercise`）。段落文字會跟著語言換，UI test 要靠 id 定位。
    /// 呼叫端決定前綴——同一個元件在多個畫面用，寫死在元件裡就撞名了。
    private let identifierPrefix: String?
    @Namespace private var pill

    public init(selection: Binding<Value>, options: [Option], identifierPrefix: String? = nil) {
        self._selection = selection
        self.options = options
        self.identifierPrefix = identifierPrefix
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
                .modifier(OptionalIdentifier(id: identifierPrefix.map { "\($0).\(option.value)" }))
            }
        }
        .padding(4)
        .background(Capsule().fill(TLColor.neutral200))
    }
}
