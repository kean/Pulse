// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Pulse", targets: ["Pulse"]),
        .library(name: "PulseProxy", targets: ["PulseProxy"]),
        .library(name: "PulseUI", targets: ["PulseUI"]),
    ],
    targets: [
        .target(name: "Pulse", resources: [.process("PrivacyInfo.xcprivacy")]),
        .target(name: "PulseProxy", dependencies: ["Pulse"]),
        .target(
            name: "PulseUI", dependencies: ["Pulse"], resources: [.process("PrivacyInfo.xcprivacy")]
        ),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
