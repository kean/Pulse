// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v14),
        .tvOS(.v15),
        .macOS(.v12),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "Pulse", targets: ["Pulse"]),
        .library(name: "PulseUI", targets: ["PulseUI"])
    ],
    targets: [
        .target(name: "Pulse"),
        .target(name: "PulseUI", dependencies: ["Pulse"]),
        .testTarget(name: "PulseTests", dependencies: ["Pulse"]),
        .testTarget(name: "PulseUITests", dependencies: ["PulseUI"])
    ]
)
