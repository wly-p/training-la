// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Ability",
    defaultLocalization: "zh-Hant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AbilityDomain", targets: ["AbilityDomain"]),
        .library(name: "AbilityData", targets: ["AbilityData"]),
        .library(name: "AbilityPresentation", targets: ["AbilityPresentation"]),
    ],
    dependencies: [
        .package(path: "../SharedKernel"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "AbilityDomain", dependencies: ["SharedKernel"]),
        .target(name: "AbilityData", dependencies: ["AbilityDomain"]),
        .target(
            name: "AbilityPresentation",
            dependencies: [
                "AbilityDomain",
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            resources: [.process("Localizable.xcstrings")]
        ),
        .testTarget(name: "AbilityDomainTests", dependencies: ["AbilityDomain"]),
        .testTarget(name: "AbilityDataTests", dependencies: ["AbilityData"]),
        .testTarget(name: "AbilityPresentationTests", dependencies: ["AbilityPresentation"]),
    ]
)
