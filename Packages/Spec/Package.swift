// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Spec",
    defaultLocalization: "zh-Hant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SpecDomain", targets: ["SpecDomain"]),
        .library(name: "SpecData", targets: ["SpecData"]),
        .library(name: "SpecPresentation", targets: ["SpecPresentation"]),
    ],
    dependencies: [
        .package(path: "../SharedKernel")
    ],
    targets: [
        .target(
            name: "SpecDomain",
            dependencies: ["SharedKernel"]
        ),
        .target(
            name: "SpecData",
            dependencies: ["SpecDomain"]
        ),
        .target(
            name: "SpecPresentation",
            dependencies: ["SpecDomain"],
            resources: [.process("Localizable.xcstrings")]
        ),
        .testTarget(
            name: "SpecDomainTests",
            dependencies: ["SpecDomain"]
        ),
        .testTarget(
            name: "SpecDataTests",
            dependencies: ["SpecData"]
        ),
        .testTarget(
            name: "SpecPresentationTests",
            dependencies: ["SpecPresentation"]
        ),
    ]
)
