// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Reminders",
    defaultLocalization: "zh-Hant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RemindersDomain", targets: ["RemindersDomain"]),
        .library(name: "RemindersKit", targets: ["RemindersKit"]),
    ],
    dependencies: [
        .package(path: "../SharedKernel")
    ],
    targets: [
        // 純邏輯：偏好、port、依「偏好 × App 狀態」fan-out 的 dispatcher。無任何 Apple 框架依賴，可測。
        .target(name: "RemindersDomain"),
        // 平台實作：本地通知、聲音、UserDefaults 偏好儲存。依 SharedKernel：背景通知內容要在排程當下
        // 明確解析目前語言（見 UserNotificationRestScheduler，沒有 SwiftUI Environment 可用）。
        .target(
            name: "RemindersKit",
            dependencies: ["RemindersDomain", "SharedKernel"],
            resources: [.process("Localizable.xcstrings")]
        ),
        .testTarget(
            name: "RemindersDomainTests",
            dependencies: ["RemindersDomain"]
        ),
        .testTarget(
            name: "RemindersKitTests",
            dependencies: ["RemindersKit", "SharedKernel"]
        ),
    ]
)
