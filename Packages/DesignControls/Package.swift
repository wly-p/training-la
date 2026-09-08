// swift-tools-version:6.0
import PackageDescription

// 互動控制項：有內部狀態、手勢、或排版計算的元件。
//
// 為什麼跟 DesignSystem 分開：DesignSystem 是**純呈現** ——
// 給 props 就畫，沒有 @State、沒有計算。一旦元件要自己記住捲到哪、
// 要算滾輪停在第幾格、要把 Double 轉成顯示字串，它就不是「元件」而是「控制項」。
//
// 相依方向單向：DesignControls → DesignSystem（控制項用得到原子與 token），反向不行。
let package = Package(
    name: "DesignControls",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DesignControls", targets: ["DesignControls"])
    ],
    dependencies: [
        .package(path: "../DesignSystem")
    ],
    targets: [
        .target(name: "DesignControls", dependencies: ["DesignSystem"]),
        // 控制項本身測不動（View），但它們的排版數學是純函式，測得到也值得測。
        .testTarget(name: "DesignControlsTests", dependencies: ["DesignControls"])
    ]
)
