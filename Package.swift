// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeLimits",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ClaudeLimits", path: "Sources/ClaudeLimits")
    ]
)
