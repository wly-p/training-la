// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Plan",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlanDomain", targets: ["PlanDomain"]),
        .library(name: "PlanData", targets: ["PlanData"]),
        .library(name: "PlanPresentation", targets: ["PlanPresentation"]),
    ],
    dependencies: [
        .package(path: "../SharedKernel")
    ],
    targets: [
        .target(name: "PlanDomain", dependencies: ["SharedKernel"]),
        .target(name: "PlanData", dependencies: ["PlanDomain"]),
        .target(name: "PlanPresentation", dependencies: ["PlanDomain"]),
        .testTarget(name: "PlanDomainTests", dependencies: ["PlanDomain"]),
        .testTarget(name: "PlanDataTests", dependencies: ["PlanData"]),
    ]
)
