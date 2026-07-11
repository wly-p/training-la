import SharedKernel
import SwiftUI

@main
struct TrainingLaApp: App {
    private let dependencies: AppDependencies
    private let environment: AppEnvironment

    init() {
        // 環境由 build configuration 經 Info.plist 決定（dev/prod）
        environment = AppEnvironment.resolve(infoDictionary: Bundle.main.infoDictionary ?? [:])
        do {
            let inMemory = CommandLine.arguments.contains("--uitest-inmemory")
            dependencies = try AppDependencies.live(inMemory: inMemory)
        } catch {
            fatalError("無法初始化資料層：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies, environment: environment)
        }
    }
}
