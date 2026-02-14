// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "applpass",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "applpass", targets: ["ApplPass"]),
  ],
  dependencies: [
    .package(path: "Vendor/swift-argument-parser"),
    .package(path: "Vendor/swift-format"),
  ],
  targets: [
    .executableTarget(
      name: "ApplPass",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SwiftFormat", package: "swift-format"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "ApplPassTests",
      dependencies: ["ApplPass"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
