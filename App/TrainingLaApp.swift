import SwiftUI

@main
struct TrainingLaApp: App {
    private let dependencies: AppDependencies

    init() {
        do {
            dependencies = try AppDependencies.live()
        } catch {
            fatalError("無法初始化資料層：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
