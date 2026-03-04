// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageBar",
            path: "Sources",
            exclude: ["Info.plist"],
            resources: [.copy("Resources/statusline-command.sh")]
        )
    ]
)
