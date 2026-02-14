import ArgumentParser

@main
struct ApplPass: ParsableCommand {
  static let version = "0.1.0"

  static let configuration = CommandConfiguration(
    abstract: "CLI for managing passwords in macOS Keychain",
    version: version
  )

  mutating func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let subcommand = arguments.first else {
      throw ApplPassCommandError.missingSubcommand
    }

    switch subcommand {
    case "get":
      var command = try GetCommand.parse(arguments: Array(arguments.dropFirst()))
      try command.run()
    default:
      throw ApplPassCommandError.unknownSubcommand(subcommand)
    }
  }
}

enum ApplPassCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingSubcommand
  case unknownSubcommand(String)

  var description: String {
    switch self {
    case .missingSubcommand:
      return "Missing command. Available commands: get."
    case .unknownSubcommand(let name):
      return "Unknown command '\(name)'. Available commands: get."
    }
  }
}
