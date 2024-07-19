// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "oramacloud-client",
    products: [
        .library(
            name: "oramacloud-client",
            targets: ["oramacloud-client"]
        ),
    ],
    targets: [
        .target(name: "oramacloud-client"),
        .testTarget(
            name: "oramacloud-clientTests",
            dependencies: ["oramacloud-client"]
        ),
    ]
)
