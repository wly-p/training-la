// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "History",
    defaultLocalization: "zh-Hant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HistoryDomain", targets: ["HistoryDomain"]),
        .library(name: "HistoryPresentation", targets: ["HistoryPresentation"]),
    ],
    dependencies: [
        .package(path: "../SharedKernel")
    ],
    targets: [
        .target(
            name: "HistoryDomain",
            dependencies: ["SharedKernel"]
        ),
        .target(
            name: "HistoryPresentation",
            dependencies: ["HistoryDomain"],
            resources: [.process("Localizable.xcstrings")]
        ),
        .testTarget(
            name: "HistoryPresentationTests",
            dependencies: ["HistoryPresentation"]
        ),
    ]
)
