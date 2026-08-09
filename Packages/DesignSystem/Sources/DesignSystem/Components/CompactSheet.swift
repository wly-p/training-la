import SwiftUI

/// 「取消 / 標題 / 完成」＋ 一段內容的底部 sheet 外框（數值選擇器那一類都用它）。
///
/// 存在的理由是兩個實際踩到的版面 bug：
/// 1. **高度寫死**。各處各自 `.presentationDetents([.height(260/520/560)])`，一改內容就破：
///    太小 → 內容被壓扁、右上角「完成」蓋到下面的東西；太大 → 底下留一塊空白。
///    這裡改成量測內容的理想高度再當 detent，內容變了自己跟著變。
/// 2. **底色沒鋪滿**。內容 VStack 只有內容那麼高，`.background` 掛在它身上時，sheet 其餘區域
///    沒被塗到，露出底下畫面的模糊 —— 看起來就是「上方多出一塊空白／殘影」。
///    所以這裡先撐滿再上底色。
///
/// 內容用 `fixedSize(vertical:)` 取理想高度，不會被「還沒量到、暫時是 0」的 sheet 高度壓扁，
/// 量測因此第一輪就穩定。
public struct CompactSheet<Content: View>: View {
    private let title: Text
    private let cancelTitle: Text?
    private let confirmTitle: Text
    private let onCancel: (() -> Void)?
    private let onConfirm: () -> Void
    private let content: Content

    @State private var contentHeight: CGFloat = 0
    @State private var bottomInset: CGFloat = 0

    /// - Parameters:
    ///   - cancelTitle: nil＝不顯示取消（只有「完成」的情境，如訓練中改重量）。
    public init(
        title: Text,
        cancelTitle: Text? = nil,
        confirmTitle: Text,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapL) {
            topBar
            content
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.top, TLSpace.gapL)
        .padding(.bottom, TLSpace.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 內容取理想高度：sheet 高度還沒算出來時也不會被壓扁，量到的才是真的。
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: CompactSheetHeightKey.self, value: geo.size.height)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 撐滿之後才上底色，sheet 才不會有一塊沒塗到的殘影。
        .background(TLColor.bg)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: CompactSheetBottomInsetKey.self, value: geo.safeAreaInsets.bottom)
            }
        )
        .onPreferenceChange(CompactSheetHeightKey.self) { contentHeight = $0 }
        .onPreferenceChange(CompactSheetBottomInsetKey.self) { bottomInset = $0 }
        .presentationDetents([.height(contentHeight + bottomInset)])
        .presentationDragIndicator(.visible)
    }

    /// 標題用 overlay 置中，不跟左右按鈕搶 HStack 的空間 —— 否則沒有「取消」時標題會偏掉。
    private var topBar: some View {
        HStack {
            if let cancelTitle, let onCancel {
                Button(action: onCancel) { cancelTitle }
                    .font(TLFont.zh(15.5, .medium))
                    .foregroundStyle(TLColor.neutral600)
            }
            Spacer(minLength: TLSpace.gapM)
            Button(action: onConfirm) { confirmTitle }
                .font(TLFont.zh(15.5, .bold))
                .foregroundStyle(TLColor.accent700)
        }
        .overlay {
            title
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.text)
                .lineLimit(1)
        }
    }
}

private struct CompactSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct CompactSheetBottomInsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
