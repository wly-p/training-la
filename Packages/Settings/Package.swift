// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SettingsPresentation", targets: ["SettingsPresentation"])
    ],
    dependencies: [
        .package(path: "../Reminders")
    ],
    targets: [
        .target(
            name: "SettingsPresentation",
            dependencies: [.product(name: "RemindersDomain", package: "Reminders")]
        ),
        .testTarget(
            name: "SettingsPresentationTests",
            dependencies: ["SettingsPresentation"]
        ),
    ]
)
