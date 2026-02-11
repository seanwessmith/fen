// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FenCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "FenModels", targets: ["FenModels"]),
        .library(name: "FenDataStore", targets: ["FenDataStore"]),
        .library(name: "FenSync", targets: ["FenSync"]),
        .library(name: "FenMedia", targets: ["FenMedia"]),
        .library(name: "FenPermissions", targets: ["FenPermissions"]),
        .library(name: "FenNetworking", targets: ["FenNetworking"]),
        .library(name: "FenTelemetry", targets: ["FenTelemetry"])
    ],
    dependencies: [],
    targets: [
        .target(name: "FenModels"),
        .target(name: "FenDataStore", dependencies: ["FenModels"]),
        .target(name: "FenNetworking", dependencies: ["FenModels"]),
        .target(name: "FenPermissions", dependencies: ["FenModels"]),
        .target(name: "FenTelemetry"),
        .target(name: "FenMedia", dependencies: ["FenModels"]),
        .target(
            name: "FenSync",
            dependencies: [
                "FenModels",
                "FenDataStore",
                "FenNetworking",
                "FenPermissions",
                "FenTelemetry"
            ]
        ),
        .testTarget(
            name: "FenDataStoreTests",
            dependencies: ["FenDataStore", "FenModels"]
        )
    ]
)
