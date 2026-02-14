// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "applpass",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "applpass", targets: ["ApplPass"]),
  ],
  targets: [
    .executableTarget(
      name: "ApplPass",
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
