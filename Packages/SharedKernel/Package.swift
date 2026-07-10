// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SharedKernel",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SharedKernel", targets: ["SharedKernel"])
    ],
    targets: [
        .target(name: "SharedKernel")
    ]
)
