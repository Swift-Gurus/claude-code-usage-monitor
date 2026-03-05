// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ClaudeUsageBarLib",
            path: "Sources",
            exclude: ["Info.plist", "App"],
            resources: [.copy("Resources/statusline-command.sh")]
        ),
        .executableTarget(
            name: "ClaudeUsageBar",
            dependencies: ["ClaudeUsageBarLib"],
            path: "Sources/App"
        ),
        .testTarget(
            name: "ClaudeUsageBarTests",
            dependencies: ["ClaudeUsageBarLib"],
            path: "Tests"
        )
    ]
)
