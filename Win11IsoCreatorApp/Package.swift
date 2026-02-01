// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Win11IsoCreatorApp",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // The executable product for the app
        .executable(
            name: "Win11IsoCreatorApp",
            targets: ["Win11IsoCreatorApp"]
        )
    ],
    targets: [
        // The target for the executable
        .executableTarget(
            name: "Win11IsoCreatorApp",
            path: "Sources/Win11IsoCreatorApp"
        )
    ]
)
