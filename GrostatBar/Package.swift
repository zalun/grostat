// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrostatBar",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "GrostatBar",
            dependencies: [
                .product(name: "GrostatShared", package: "growatt-stats"),
            ],
            path: "Sources",
            exclude: ["logo.png", "AppIcon.icns"],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Network"),
            ]
        ),
    ]
)
