// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Settings",
    defaultLocalization: "zh-Hant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SettingsPresentation", targets: ["SettingsPresentation"])
    ],
    dependencies: [
        .package(path: "../Reminders"),
        .package(path: "../SharedKernel"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "SettingsPresentation",
            dependencies: [
                .product(name: "RemindersDomain", package: "Reminders"),
                .product(name: "SharedKernel", package: "SharedKernel"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            resources: [.process("Localizable.xcstrings")]
        ),
        .testTarget(
            name: "SettingsPresentationTests",
            dependencies: [
                "SettingsPresentation",
                .product(name: "SharedKernel", package: "SharedKernel"),
            ]
        ),
    ]
)
