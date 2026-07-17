// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Training",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TrainingDomain", targets: ["TrainingDomain"]),
        .library(name: "TrainingData", targets: ["TrainingData"]),
        .library(name: "TrainingPresentation", targets: ["TrainingPresentation"]),
    ],
    dependencies: [
        .package(path: "../SharedKernel"),
        .package(path: "../Reminders"),
    ],
    targets: [
        .target(
            name: "TrainingDomain",
            dependencies: ["SharedKernel"]
        ),
        .target(
            name: "TrainingData",
            dependencies: ["TrainingDomain"]
        ),
        .target(
            name: "TrainingPresentation",
            dependencies: ["TrainingDomain", .product(name: "RemindersDomain", package: "Reminders")]
        ),
        .testTarget(
            name: "TrainingDomainTests",
            dependencies: ["TrainingDomain"]
        ),
        .testTarget(
            name: "TrainingDataTests",
            dependencies: ["TrainingData"]
        ),
        .testTarget(
            name: "TrainingPresentationTests",
            dependencies: ["TrainingPresentation"]
        ),
    ]
)
