import SwiftUI

/// L1 原子。水平進度條。
///
/// 規格：`design-system/atoms/TLProgressBar/TLProgressBar.spec.md`
///
/// 軌道色是 prop 而不是固定值：這個元件會疊在不同底色上
/// （群組容器 `surfaceRaised` 或卡片底），軌道要比它所在的底稍深才看得出來。
public struct TLProgressBar: View {
    private let ratio: Double
    private let track: Color

    public init(ratio: Double, track: Color = TLColor.surfaceTrack) {
        self.ratio = ratio
        self.track = track
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(TLColor.actionPrimary)
                    .frame(width: geo.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: TLSize.progressBar)
    }
}
