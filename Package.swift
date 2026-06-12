// swift-tools-version:5.10
import PackageDescription
import Foundation

// The standalone Pulse demo/example apps need the mock data and demo views
// (gated behind `STANDALONE_PULSE_APP` in Sources/PulseUI/Mocks) compiled into
// release builds. Enable it by building with `STANDALONE_PULSE_APP=1` in the
// environment; it stays off for apps that embed Pulse so mocks never ship.
let pulseUISwiftSettings: [SwiftSetting] = ProcessInfo.processInfo
    .environment["STANDALONE_PULSE_APP"] != nil ? [.define("STANDALONE_PULSE_APP")] : []

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
        .library(name: "PulseUI", targets: ["PulseUI"]),
    ],
    targets: [
        .target(name: "Pulse", dependencies: ["PulseObjCHelpers"]),
        .target(name: "PulseProxy", dependencies: ["Pulse"]),
        .target(name: "PulseUI", dependencies: ["Pulse"], swiftSettings: pulseUISwiftSettings),
        .target(name: "PulseObjCHelpers"),
        .testTarget(name: "PulseUITests", dependencies: ["PulseUI"]),
    ]
)
