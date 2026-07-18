import SharedKernel
import SwiftUI

@main
struct TrainingLaApp: App {
    private let dependencies: AppDependencies

    init() {
        do {
            let inMemory = CommandLine.arguments.contains("--uitest-inmemory")
            dependencies = try AppDependencies.live(inMemory: inMemory)
        } catch {
            fatalError("無法初始化資料層：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView(dependencies: dependencies)
        }
    }
}

/// 持有「重置權杖」的穩定外層：清除所有資料後換一個 token，用 `.id` 逼 `RootView` 整棵重建，
/// 讓各分頁的 ViewModel 重新讀取（已清空的）store，回到全新初始狀態。
private struct RootContainerView: View {
    let dependencies: AppDependencies
    @State private var resetToken = UUID()

    var body: some View {
        RootView(
            dependencies: dependencies,
            onEraseAll: { resetToken = UUID() }
        )
        .id(resetToken)
    }
}
