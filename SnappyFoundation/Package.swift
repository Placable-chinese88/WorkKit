// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SnappyFoundation",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
  ],
  products: [
    .library(
      name: "SnappyFoundation",
      targets: ["SnappyFoundation"]
    )
  ],
  targets: [
    // Binary target for the precompiled snappy library
    .binaryTarget(
      name: "libsnappy",
      path: "Sources/libsnappy.xcframework"
    ),

    // C wrapper target
    .target(
      name: "snappyc",
      dependencies: ["libsnappy"],
      linkerSettings: [.linkedLibrary("c++")]
    ),

    // Swift wrapper target
    .target(
      name: "SnappyFoundation",
      dependencies: ["snappyc"]
    ),

    // Tests
    .testTarget(
      name: "SnappyFoundationTests",
      dependencies: ["SnappyFoundation"],
      linkerSettings: [.linkedLibrary("c++")]
    ),
  ]
)
