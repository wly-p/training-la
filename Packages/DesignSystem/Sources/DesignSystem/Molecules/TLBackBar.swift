import SwiftUI

/// L2 分子。drill-in 子頁左上角的返回列。
///
/// 規格：`design-system/molecules/TLBackBar/TLBackBar.spec.md`
///
/// 由 `TLCircleIconButton`（L1）組成，靠左，右側可放一個操作。
///
/// 上邊距用 `TLSpace.gapS`：返回鈕是 44×44 的觸控區、圓形視覺本體比觸控區小，
/// 上緣本來就自帶留白，再多給會把主標推得太低。
public struct TLBackBar<Trailing: View>: View {
    private let onBack: () -> Void
    private let trailing: Trailing

    public init(onBack: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.onBack = onBack
        self.trailing = trailing()
    }

    public var body: some View {
        HStack {
            TLCircleIconButton(systemImage: "chevron.left", style: .outline, action: onBack)
            Spacer()
            trailing
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.top, TLSpace.gapS)
    }
}

public extension TLBackBar where Trailing == EmptyView {
    /// 右側沒有操作的返回列。
    init(onBack: @escaping () -> Void) {
        self.init(onBack: onBack) { EmptyView() }
    }
}
