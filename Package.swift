// swift-tools-version:5.9

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
        .library(name: "PulseUI", targets: ["PulseUI"]),
        .library(name: "PulseComponents", targets: ["PulseComponents"]),
    ],
    targets: [
        .target(name: "Pulse"),
        .target(name: "PulseUI", dependencies: ["Pulse", "PulseComponents"]),
        .target(name: "PulseComponents", dependencies: ["Pulse"]),
        .testTarget(name: "PulseTests", dependencies: ["Pulse"]),
        .testTarget(name: "PulseUITests", dependencies: ["PulseUI"])
    ],
    swiftLanguageVersions: [
      .v5
    ]
)
