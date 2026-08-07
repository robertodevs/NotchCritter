// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchCritter",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NotchCritter",
            path: "Sources/NotchCritter",
            resources: [
                .copy("Resources/Sprites")
            ]
        )
    ]
)
