// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TalkTimer",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TalkTimerCore", targets: ["TalkTimerCore"]),  // lu par le futur projet Xcode (SPECS § 9)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.9.0"),  // version exacte (SPECS § 9)
    ],
    targets: [
        .target(name: "TalkTimerCore", dependencies: [.product(name: "Markdown", package: "swift-markdown")]),
        .testTarget(name: "TalkTimerCoreTests", dependencies: ["TalkTimerCore"]),
    ]
)
