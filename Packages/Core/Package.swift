// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeronCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "HeronModels", targets: ["HeronModels"]),
        .library(name: "HeronDataStore", targets: ["HeronDataStore"]),
        .library(name: "HeronSync", targets: ["HeronSync"]),
        .library(name: "HeronMedia", targets: ["HeronMedia"]),
        .library(name: "HeronPermissions", targets: ["HeronPermissions"]),
        .library(name: "HeronNetworking", targets: ["HeronNetworking"]),
        .library(name: "HeronTelemetry", targets: ["HeronTelemetry"])
    ],
    dependencies: [],
    targets: [
        .target(name: "HeronModels"),
        .target(name: "HeronDataStore", dependencies: ["HeronModels"]),
        .target(name: "HeronNetworking", dependencies: ["HeronModels"]),
        .target(name: "HeronPermissions", dependencies: ["HeronModels"]),
        .target(name: "HeronTelemetry"),
        .target(name: "HeronMedia", dependencies: ["HeronModels"]),
        .target(
            name: "HeronSync",
            dependencies: [
                "HeronModels",
                "HeronDataStore",
                "HeronNetworking",
                "HeronPermissions",
                "HeronTelemetry"
            ]
        ),
        .testTarget(
            name: "HeronDataStoreTests",
            dependencies: ["HeronDataStore", "HeronModels"]
        )
    ]
)
