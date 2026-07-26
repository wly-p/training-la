// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Ability",
    defaultLocalization: "zh-Hant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AbilityDomain", targets: ["AbilityDomain"]),
        .library(name: "AbilityData", targets: ["AbilityData"]),
    ],
    dependencies: [
        .package(path: "../SharedKernel")
    ],
    targets: [
        .target(name: "AbilityDomain", dependencies: ["SharedKernel"]),
        .target(name: "AbilityData", dependencies: ["AbilityDomain"]),
        .testTarget(name: "AbilityDomainTests", dependencies: ["AbilityDomain"]),
        .testTarget(name: "AbilityDataTests", dependencies: ["AbilityData"]),
    ]
)
