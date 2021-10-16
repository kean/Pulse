// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v11),
        .watchOS(.v6),
        .macOS(.v11),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "Pulse", targets: ["Pulse"]),
        .library(name: "PulseCore", targets: ["PulseCore"]),
        .library(name: "PulseUI", targets: ["PulseUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "PulseUI", dependencies: ["PulseCore"], path: "Pulse/Sources/PulseUI"),
        .target(name: "Pulse", dependencies: [.product(name: "Logging", package: "swift-log"), "PulseCore"], path: "Pulse/Sources/Pulse"),
        .target(name: "PulseCore", dependencies: ["PulseInternal"], path: "Pulse/Sources/PulseCore"),
        .target(name: "PulseInternal", path: "Pulse/Sources/PulseInternal"),
        .testTarget(name: "PulseTests", dependencies: ["Pulse"], path: "Pulse/Tests/PulseTests", resources: [.process("Resources")])
    ]
)
