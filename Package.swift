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
