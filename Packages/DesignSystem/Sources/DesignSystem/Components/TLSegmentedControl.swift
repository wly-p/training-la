import SwiftUI

/// 分段控制的兩種尺寸（handoff-20 B 節）。
///
/// `regular`＝全寬導航切換器（歷史依日期／依動作、動作庫四分頁…）：它回答的是「頁面現在在看什麼」，
/// 本來就該有份量，所以字級 15、選中膠囊帶 shadow。
///
/// `compact`＝設定列右側（重量單位）：它只是「一個欄位的值」，跟同組其他列的值文字同級。
/// 拿掉 shadow、縮 padding，整顆高 26pt 才不會把 56pt 的列撐高、也不會變成全頁最亮的元素。
public enum TLSegmentedControlSize: Sendable {
    case regular, compact

    var trackPadding: CGFloat { self == .regular ? 4 : 2 }
    var itemPaddingV: CGFloat { self == .regular ? 10 : 5 }
    /// `nil`＝每項平分寬度（全寬用）；有值＝依內容寬 ＋ 這個左右 padding。
    var itemPaddingH: CGFloat? { self == .regular ? nil : 13 }
    var fontSize: CGFloat { self == .regular ? TLFont.rowTitle : 12 }
    var selectedShadow: TLShadow.Style? { self == .regular ? TLShadow.sm : nil }
}

/// 模板 5：分段控制。
/// 軌道：capsule、`neutral-200`、padding 4。
/// 選中項：`bg` 白底 capsule ＋ shadow-sm、weight 700。
/// 未選：weight 500、`neutral-600`。每項垂直 padding 10。
/// 切換時選中膠囊滑動過去（0.2s ease-out）。
///
/// 設定列裡請用 `size: .compact`（見 `TLSegmentedControlSize`）。
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
    private let size: TLSegmentedControlSize
    @Namespace private var pill

    public init(
        selection: Binding<Value>,
        options: [Option],
        identifierPrefix: String? = nil,
        size: TLSegmentedControlSize = .regular
    ) {
        self._selection = selection
        self.options = options
        self.identifierPrefix = identifierPrefix
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = option.value }
                } label: {
                    option.label
                        .font(TLFont.zh(size.fontSize, isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? TLColor.text : TLColor.neutral600)
                        .modifier(SegmentWidth(paddingH: size.itemPaddingH))
                        .padding(.vertical, size.itemPaddingV)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(TLColor.bg)
                                    .modifier(OptionalShadow(style: size.selectedShadow))
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .modifier(OptionalIdentifier(id: identifierPrefix.map { "\($0).\(option.value)" }))
            }
        }
        .padding(size.trackPadding)
        .background(Capsule().fill(TLColor.neutral200))
    }
}

/// 每一段的寬度：`nil`＝平分（全寬導航用）；有值＝內容寬 ＋ 左右 padding（設定列用）。
private struct SegmentWidth: ViewModifier {
    let paddingH: CGFloat?
    func body(content: Content) -> some View {
        if let paddingH {
            content.padding(.horizontal, paddingH)
        } else {
            content.frame(maxWidth: .infinity)
        }
    }
}

/// compact 不上 shadow——它不該是全頁最亮的元素。
private struct OptionalShadow: ViewModifier {
    let style: TLShadow.Style?
    func body(content: Content) -> some View {
        if let style {
            content.tlShadow(style)
        } else {
            content
        }
    }
}
