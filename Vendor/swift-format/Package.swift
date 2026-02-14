// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "swift-format",
  products: [
    .library(name: "SwiftFormat", targets: ["SwiftFormat"]),
  ],
  targets: [
    .target(name: "SwiftFormat"),
  ],
  swiftLanguageModes: [.v6]
)
