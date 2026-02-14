import ArgumentParser

@main
struct ApplPass: ParsableCommand {
  static let version = "0.1.0"

  static let configuration = CommandConfiguration(
    abstract: "CLI for managing passwords in macOS Keychain",
    version: version
  )
}
