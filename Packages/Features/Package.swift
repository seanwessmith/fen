// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FenFeatures",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "FenFeatureCapture", targets: ["FenFeatureCapture"]),
        .library(name: "FenFeatureJournal", targets: ["FenFeatureJournal"]),
        .library(name: "FenFeatureNearby", targets: ["FenFeatureNearby"]),
        .library(name: "FenFeatureTrends", targets: ["FenFeatureTrends"]),
        .library(name: "FenFeatureSettings", targets: ["FenFeatureSettings"]),
        .library(name: "FenFeatureOnboarding", targets: ["FenFeatureOnboarding"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../UI")
    ],
    targets: [
        .target(
            name: "FenFeatureCapture",
            dependencies: [
                .product(name: "FenModels", package: "Core"),
                .product(name: "FenDataStore", package: "Core"),
                .product(name: "FenMedia", package: "Core"),
                .product(name: "FenSync", package: "Core"),
                .product(name: "FenUIKitComponents", package: "UI"),
                .product(name: "FenSwiftUIComponents", package: "UI")
            ]
        ),
        .target(
            name: "FenFeatureJournal",
            dependencies: [
                .product(name: "FenModels", package: "Core"),
                .product(name: "FenDataStore", package: "Core"),
                .product(name: "FenMedia", package: "Core"),
                .product(name: "FenSwiftUIComponents", package: "UI"),
                .product(name: "FenDesignSystem", package: "UI")
            ]
        ),
        .target(
            name: "FenFeatureNearby",
            dependencies: [
                .product(name: "FenModels", package: "Core"),
                .product(name: "FenSwiftUIComponents", package: "UI")
            ]
        ),
        .target(
            name: "FenFeatureTrends",
            dependencies: [
                .product(name: "FenModels", package: "Core"),
                .product(name: "FenSwiftUIComponents", package: "UI")
            ]
        ),
        .target(
            name: "FenFeatureSettings",
            dependencies: [
                .product(name: "FenModels", package: "Core"),
                .product(name: "FenPermissions", package: "Core"),
                .product(name: "FenSwiftUIComponents", package: "UI"),
                .product(name: "FenDesignSystem", package: "UI")
            ]
        ),
        .target(
            name: "FenFeatureOnboarding",
            dependencies: [
                .product(name: "FenModels", package: "Core"),
                .product(name: "FenSwiftUIComponents", package: "UI"),
                .product(name: "FenDesignSystem", package: "UI")
            ]
        )
    ]
)
