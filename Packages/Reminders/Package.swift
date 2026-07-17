// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Reminders",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RemindersDomain", targets: ["RemindersDomain"]),
        .library(name: "RemindersKit", targets: ["RemindersKit"]),
    ],
    targets: [
        // 純邏輯：偏好、port、依「偏好 × App 狀態」fan-out 的 dispatcher。無任何 Apple 框架依賴，可測。
        .target(name: "RemindersDomain"),
        // 平台實作：本地通知、聲音、UserDefaults 偏好儲存。
        .target(
            name: "RemindersKit",
            dependencies: ["RemindersDomain"]
        ),
        .testTarget(
            name: "RemindersDomainTests",
            dependencies: ["RemindersDomain"]
        ),
    ]
)
