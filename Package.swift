// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "grostat",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GrostatShared", targets: ["GrostatShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "GrostatShared",
            path: "Sources/GrostatShared"
        ),
        .executableTarget(
            name: "grostat",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "GrostatShared",
            ],
            path: "Sources/grostat",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
