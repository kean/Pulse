// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v11),
        .macOS(.v11),
        .watchOS(.v6),
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
        .target(
            name: "Pulse",
            dependencies: [.product(name: "Logging", package: "swift-log"), "PulseCore"],
            path: "Sources/Pulse"
        ),
        .binaryTarget(
            name: "PulseCore",
            url: "https://github.com/kean/Pulse/files/6354738/PulseCore-0.15.0.zip",
            checksum: "3dffa7d8032a9ec7b27dabba63d50a1afda5a5a0371c684193079c43de1b1894"
        ),
        .binaryTarget(
            name: "PulseUI",
            url: "https://github.com/kean/Pulse/files/6354740/PulseUI-0.15.0.zip",
            checksum: "ea357243b97e0c191cc54282fac9a802998ede23dacb03f57218888b9942c15f"
        )
    ]
)
