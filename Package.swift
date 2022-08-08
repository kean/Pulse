// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v11),
        .watchOS(.v7)
    ],
    products: [
        .library(name: "Pulse", targets: ["Pulse"]),
        .library(name: "PulseUI", targets: ["PulseUI"]),
        .library(name: "PulseLogHandler", targets: ["PulseLogHandler"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "Pulse"),
        .target(name: "PulseUI", dependencies: ["Pulse"]),
        .target(name: "PulseLogHandler", dependencies: [.product(name: "Logging", package: "swift-log"), "Pulse"]),
        .testTarget(name: "PulseTests", dependencies: ["Pulse"]),
        .testTarget(name: "PulseUITests", dependencies: ["PulseUI"]),
        .testTarget(name: "PulseLogHandlerTests", dependencies: ["PulseLogHandler"])
    ]
)
