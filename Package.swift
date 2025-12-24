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
        .library(name: "PulseUI", targets: ["PulseUI"]),
        .library(name: "PulseStarscream", targets: ["PulseStarscream"]),
        .library(name: "PulseApollo", targets: ["PulseApollo"])
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "Pulse"),
        .target(name: "PulseProxy", dependencies: ["Pulse"]),
        .target(name: "PulseUI", dependencies: ["Pulse"]),
        .target(name: "PulseStarscream", dependencies: ["Pulse", "Starscream"]),
        .target(name: "PulseApollo", dependencies: [
            "Pulse",
            .product(name: "ApolloWebSocket", package: "apollo-ios"),
            .product(name: "ApolloAPI", package: "apollo-ios")
        ]),
    ],
    swiftLanguageVersions: [
      .v5
    ]
)
