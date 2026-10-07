// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TalkTimer",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "TalkTimer"),
        .testTarget(name: "TalkTimerTests", dependencies: ["TalkTimer"]),
    ]
)
