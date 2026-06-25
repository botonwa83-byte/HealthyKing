// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HealthyKingKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HealthyKingKit",
            targets: ["HealthyKingKit"]
        )
    ],
    targets: [
        .target(
            name: "HealthyKingKit",
            path: "Sources/HealthyKingKit"
        ),
        .testTarget(
            name: "HealthyKingKitTests",
            dependencies: ["HealthyKingKit"],
            path: "Tests/HealthyKingKitTests"
        )
    ]
)
