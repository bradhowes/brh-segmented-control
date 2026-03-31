// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "brh-segmented-control",
  platforms: [.iOS(.v16), .macOS(.v14), .tvOS(.v15), .watchOS(.v8)],
  products: [
    .library(
      name: "BRHSegmentedControl",
      targets: ["BRHSegmentedControl"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0")
  ],
  targets: [
    .target(
      name: "BRHSegmentedControl"),
    .testTarget(
      name: "BRHSegmentedControlTests",
      dependencies: [
        "BRHSegmentedControl",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    )
  ]
)
