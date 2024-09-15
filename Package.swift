// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Pulse", targets: ["Pulse"]),
        .library(name: "PulseProxy", targets: ["PulseProxy"]),
        .library(name: "PulseUI", targets: ["PulseUI"])
    ],
    targets: [
        .target(name: "Pulse"),
        .target(name: "PulseProxy", dependencies: ["Pulse"]),
        .target(name: "PulseUI", dependencies: ["Pulse"]),
    ],
    swiftLanguageVersions: [
      .v5
    ]
)
