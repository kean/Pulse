// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
        .macOS(.v12),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "Pulse", type: .dynamic, targets: ["Pulse"]),
        .library(name: "PulseUI", type: .dynamic, targets: ["PulseUI"])
    ],
    targets: [
        .target(name: "Pulse"),
        .target(name: "PulseUI", dependencies: ["Pulse"]),
        .testTarget(name: "PulseTests", dependencies: ["Pulse"]),
        .testTarget(name: "PulseUITests", dependencies: ["PulseUI"])
    ]
)
