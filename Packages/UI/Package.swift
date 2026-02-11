// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeronUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "HeronDesignSystem", targets: ["HeronDesignSystem"]),
        .library(name: "HeronSwiftUIComponents", targets: ["HeronSwiftUIComponents"]),
        .library(name: "HeronUIKitComponents", targets: ["HeronUIKitComponents"])
    ],
    dependencies: [],
    targets: [
        .target(name: "HeronDesignSystem"),
        .target(name: "HeronSwiftUIComponents", dependencies: ["HeronDesignSystem"]),
        .target(name: "HeronUIKitComponents", dependencies: ["HeronDesignSystem"])
    ]
)
