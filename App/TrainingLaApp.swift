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
            RootView(dependencies: dependencies)
        }
    }
}
