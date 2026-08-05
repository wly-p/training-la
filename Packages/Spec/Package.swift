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
        .package(path: "../SharedKernel"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "SpecDomain",
            dependencies: ["SharedKernel"],
            // 內建動作清單（結構）與它的名稱翻譯。放 SpecDomain 而不是 SpecPresentation（那裡已有
            // 一份 catalog），是因為名稱要在 repository 層就解析成當前語言，Training / Plan /
            // History 才會一起吃到——而 SpecData 只依賴 SpecDomain。
            resources: [
                .process("Resources/OfficialExercises.json"),
                .process("Localizable.xcstrings"),
            ]
        ),
        .target(
            name: "SpecData",
            dependencies: ["SpecDomain"]
        ),
        .target(
            name: "SpecPresentation",
            dependencies: [
                "SpecDomain",
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
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
