// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DesignSystem",
    // 純視覺元件，無文案 → 不需要 defaultLocalization / String Catalog。
    // 文字由呼叫端（各 Presentation 層）傳入，維持既有 i18n 架構。
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    targets: [
        .target(
            name: "DesignSystem",
            // Caprasimo 打包成 bundle 資源，runtime 用 CoreText 註冊（見 FontRegistration.swift）。
            // SPM package 的字體不能只靠 App 的 Info.plist UIAppFonts（那只掃 main bundle）。
            resources: [.process("Resources")]
        ),
        // 元件本身測不動（View），但滾輪的幾何運算是純函式，測得到也值得測。
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"])
    ]
)
