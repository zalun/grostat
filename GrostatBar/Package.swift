// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrostatBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GrostatBar",
            path: "Sources",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
