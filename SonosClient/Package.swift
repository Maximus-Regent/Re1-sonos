// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SonosClient",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SonosClient",
            dependencies: [],
            path: "Sources/SonosClient",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("MusicKit")
            ]
        )
    ]
)
