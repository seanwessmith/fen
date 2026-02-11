// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeronFeatures",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "HeronFeatureCapture", targets: ["HeronFeatureCapture"]),
        .library(name: "HeronFeatureJournal", targets: ["HeronFeatureJournal"]),
        .library(name: "HeronFeatureNearby", targets: ["HeronFeatureNearby"]),
        .library(name: "HeronFeatureTrends", targets: ["HeronFeatureTrends"]),
        .library(name: "HeronFeatureSettings", targets: ["HeronFeatureSettings"]),
        .library(name: "HeronFeatureOnboarding", targets: ["HeronFeatureOnboarding"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../UI")
    ],
    targets: [
        .target(
            name: "HeronFeatureCapture",
            dependencies: [
                .product(name: "HeronModels", package: "Core"),
                .product(name: "HeronMedia", package: "Core"),
                .product(name: "HeronSync", package: "Core"),
                .product(name: "HeronUIKitComponents", package: "UI"),
                .product(name: "HeronSwiftUIComponents", package: "UI")
            ]
        ),
        .target(
            name: "HeronFeatureJournal",
            dependencies: [
                .product(name: "HeronModels", package: "Core"),
                .product(name: "HeronDataStore", package: "Core"),
                .product(name: "HeronSwiftUIComponents", package: "UI"),
                .product(name: "HeronDesignSystem", package: "UI")
            ]
        ),
        .target(
            name: "HeronFeatureNearby",
            dependencies: [
                .product(name: "HeronModels", package: "Core"),
                .product(name: "HeronSwiftUIComponents", package: "UI")
            ]
        ),
        .target(
            name: "HeronFeatureTrends",
            dependencies: [
                .product(name: "HeronModels", package: "Core"),
                .product(name: "HeronSwiftUIComponents", package: "UI")
            ]
        ),
        .target(
            name: "HeronFeatureSettings",
            dependencies: [
                .product(name: "HeronModels", package: "Core"),
                .product(name: "HeronPermissions", package: "Core"),
                .product(name: "HeronSwiftUIComponents", package: "UI"),
                .product(name: "HeronDesignSystem", package: "UI")
            ]
        ),
        .target(
            name: "HeronFeatureOnboarding",
            dependencies: [
                .product(name: "HeronModels", package: "Core"),
                .product(name: "HeronSwiftUIComponents", package: "UI"),
                .product(name: "HeronDesignSystem", package: "UI")
            ]
        )
    ]
)
