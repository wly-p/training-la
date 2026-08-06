// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SharedKernel",
    // MuscleGroup / Equipment 的顯示名要中英雙語。這兩個 enum 橫跨 Plan / Training / Spec /
    // History / Ability 五個 package 顯示，翻譯放各自的 catalog 會變成五份一模一樣的字串，
    // 所以由 SharedKernel 自帶一份（見 Localizable.xcstrings）。
    defaultLocalization: "zh-Hant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SharedKernel", targets: ["SharedKernel"])
    ],
    targets: [
        .target(name: "SharedKernel", resources: [.process("Localizable.xcstrings")]),
        .testTarget(name: "SharedKernelTests", dependencies: ["SharedKernel"]),
    ]
)
