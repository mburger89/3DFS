// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "3DFS",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "ThreeDFS",
            path: "Sources/ThreeDFS"
        )
    ]
)
