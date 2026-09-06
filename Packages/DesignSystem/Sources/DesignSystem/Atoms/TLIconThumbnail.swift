import SwiftUI

/// L1 原子。方形圖片縮圖（目前用於 App 圖示預覽）。
///
/// 規格：`design-system/atoms/TLIconThumbnail/TLIconThumbnail.spec.md`
///
/// 圓角 25% ≈ iOS App 圖示的 squircle 比例（22.4%），所以它讀起來像圖示而不是圓角方塊。
public struct TLIconThumbnail: View {
    private let imageName: String

    public init(imageName: String) {
        self.imageName = imageName
    }

    public var body: some View {
        Image(imageName)
            .resizable()
            .frame(width: TLSize.iconThumb, height: TLSize.iconThumb)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.iconThumb, style: .continuous))
    }
}
