import SharedKernel
import SwiftUI

private enum LaunchPhase {
    case ready(AppDependencies)
    case failed(Error)
}

@main
struct TrainingLaApp: App {
    var body: some Scene {
        WindowGroup {
            AppLaunchView()
        }
    }
}

private struct AppLaunchView: View {
    @State private var phase: LaunchPhase

    init() {
        _phase = State(initialValue: Self.attemptInit())
    }

    private static func attemptInit() -> LaunchPhase {
        let inMemory = CommandLine.arguments.contains("--uitest-inmemory")
        do {
            return .ready(try AppDependencies.live(inMemory: inMemory))
        } catch {
            return .failed(error)
        }
    }

    var body: some View {
        switch phase {
        case .ready(let dependencies):
            RootContainerView(dependencies: dependencies)
        case .failed(let error):
            LaunchErrorView(error: error) {
                phase = Self.attemptInit()
            }
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
        // DEBUG 的假資料產生器（`--debug-seed=`）。沒帶參數就什麼都不做，
        // release build 連這個 closure 都是空的。
        .task { await dependencies.seedDebugDataIfRequested() }
    }
}
