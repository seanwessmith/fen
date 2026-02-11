// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FenUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "FenDesignSystem", targets: ["FenDesignSystem"]),
        .library(name: "FenSwiftUIComponents", targets: ["FenSwiftUIComponents"]),
        .library(name: "FenUIKitComponents", targets: ["FenUIKitComponents"])
    ],
    dependencies: [],
    targets: [
        .target(name: "FenDesignSystem"),
        .target(name: "FenSwiftUIComponents", dependencies: ["FenDesignSystem"]),
        .target(name: "FenUIKitComponents", dependencies: ["FenDesignSystem"])
    ]
)
