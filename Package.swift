// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIUsageCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AIUsageCore", targets: ["AIUsageCore"]),
    ],
    targets: [
        .target(
            name: "AIUsageCore",
            path: "Shared"
        ),
        .testTarget(
            name: "AIUsageCoreTests",
            dependencies: ["AIUsageCore"],
            path: "AIUsageTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
