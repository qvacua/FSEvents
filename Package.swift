// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "EonilFSEvents",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(name: "EonilFSEvents", targets: ["EonilFSEvents"]),
    .executable(name: "EonilFSEventsDemoCLI", targets: ["EonilFSEventsDemoCLI"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(name: "EonilFSEvents", dependencies: []),
    .executableTarget(name: "EonilFSEventsDemoCLI", dependencies: ["EonilFSEvents"]),
  ]
)
