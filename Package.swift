// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Privadi",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PrivadiCore",
            targets: ["PrivadiCore"]
        ),
        .executable(
            name: "PrivadiApp",
            targets: ["PrivadiApp"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "PrivadiCore",
            dependencies: [],
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "PrivadiApp",
            dependencies: ["PrivadiCore"]
        ),
        .testTarget(
            name: "PrivadiCoreTests",
            dependencies: ["PrivadiCore"]
        ),
    ]
)
