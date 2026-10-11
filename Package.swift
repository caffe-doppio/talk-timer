// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TalkTimer",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TalkTimerCore", targets: ["TalkTimerCore"]),  // lu par le futur projet Xcode (SPECS § 9)
    ],
    targets: [
        .target(name: "TalkTimerCore"),
        .executableTarget(name: "TalkTimer", dependencies: ["TalkTimerCore"]),  // spike de la barre
        .testTarget(name: "TalkTimerCoreTests", dependencies: ["TalkTimerCore"]),
    ]
)
