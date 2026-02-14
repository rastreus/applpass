// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "swift-argument-parser",
  products: [
    .library(name: "ArgumentParser", targets: ["ArgumentParser"])
  ],
  targets: [
    .target(name: "ArgumentParser")
  ],
  swiftLanguageModes: [.v6]
)
