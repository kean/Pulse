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
            url: "https://github.com/kean/Pulse/files/6232572/PulseCore-0.14.1.zip",
            checksum: "2de43f9dea1844a27fd50bc1b872e024fcffa0e7846a3d42e5a1b97cc62996d0"
        ),
        .binaryTarget(
            name: "PulseUI",
            url: "https://github.com/kean/Pulse/files/6232576/PulseUI-0.14.1.zip",
            checksum: "869b631612633985095643a6256a92ffc92fb434245905fd39577c8628cddb8b"
        )
    ]
)
