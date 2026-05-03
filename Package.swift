// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AndroidBridge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AndroidBridgeCore", targets: ["AndroidBridgeCore"]),
        .executable(name: "AndroidBridge", targets: ["AndroidBridge"]),
        .executable(name: "AndroidBridgeCoreTests", targets: ["AndroidBridgeCoreTests"])
    ],
    targets: [
        .target(
            name: "AndroidBridgeCore"
        ),
        .executableTarget(
            name: "AndroidBridge",
            dependencies: ["AndroidBridgeCore"]
        ),
        .executableTarget(
            name: "AndroidBridgeCoreTests",
            dependencies: ["AndroidBridgeCore"]
        )
    ]
)
