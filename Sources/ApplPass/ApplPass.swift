import ArgumentParser
import Darwin
import Foundation

@main
struct ApplPass: ParsableCommand {
  static let version = Self.loadVersionFromPackage(defaultValue: "0.1.0")

  static let configuration = CommandConfiguration(
    abstract: "CLI for managing passwords in macOS Keychain",
    version: version
  )

  static func main() {
    if CommandLine.arguments.dropFirst().contains("--version") {
      print(version)
      Darwin.exit(0)
    }

    var command = Self.init()
    do {
      try command.run()
      Darwin.exit(0)
    } catch {
      fputs("\(error)\n", stderr)
      Darwin.exit(1)
    }
  }

  struct GlobalOptions: Sendable {
    @Flag(name: [.customShort("h"), .long], help: "Show help information.")
    var help = false

    @Flag(name: .long, help: "Show version information.")
    var version = false
  }

  @OptionGroup
  var globalOptions = GlobalOptions()

  static let supportedSubcommands = ["get", "list", "add", "update", "delete", "generate"]

  static func rootHelpText(executableName: String = "applpass") -> String {
    """
    \(executableName) \(version)
    \(configuration.abstract)

    USAGE:
      \(executableName) <command> [options]

    COMMANDS:
      get       Retrieve one password from keychain.
      list      List passwords from keychain.
      add       Add a password to keychain.
      update    Update a password in keychain.
      delete    Delete a password from keychain.
      generate  Generate standalone passwords.

    GLOBAL OPTIONS:
      -h, --help   Show help information.
      --version    Show version information.

    EXAMPLES:
      \(executableName) list --service github.com
      \(executableName) get --service github.com --account bot@example.com --value-only
      \(executableName) add --service github.com --account bot@example.com --stdin
    """
  }

  static func subcommandHelpText(
    for subcommand: String,
    executableName: String = "applpass"
  ) -> String? {
    switch subcommand {
    case "get":
      """
      USAGE:
        \(executableName) get --service <service> --account <account> [options]

      OPTIONS:
        -s, --service <service>    Service name.
        -a, --account <account>    Account name.
        -f, --format <format>      Output format: table, json, csv, plain.
        -c, --clipboard            Copy password to clipboard.
        -v, --value-only           Output only the password value.
        -h, --help                 Show help information.

      EXAMPLES:
        \(executableName) get --service github.com --account bot@example.com
        \(executableName) get -s github.com -a bot@example.com --clipboard
      """
    case "list":
      """
      USAGE:
        \(executableName) list [options]

      OPTIONS:
        -s, --service <service>    Filter by service.
        -a, --account <account>    Filter by account.
        -q, --search <text>        Case-insensitive search filter.
        -f, --format <format>      Output format: table, json, csv, plain.
        --shared-only              Include only shared items.
        --personal-only            Include only personal items.
        --show-passwords           Include password values.
        -h, --help                 Show help information.

      EXAMPLES:
        \(executableName) list --search github --format table
        \(executableName) list --shared-only --format json
      """
    case "add":
      """
      USAGE:
        \(executableName) add --service <service> --account <account> [options]

      OPTIONS:
        -s, --service <service>    Service name.
        -a, --account <account>    Account name.
        -l, --label <label>        Optional label.
        --stdin                    Read password from stdin.
        -g, --generate             Generate password automatically.
        -n, --length <length>      Generated password length.
        --sync                     Enable iCloud sync for the item.
        -h, --help                 Show help information.

      EXAMPLES:
        \(executableName) add --service github.com --account bot@example.com --stdin
        \(executableName) add -s github.com -a bot@example.com --generate --length 48
      """
    case "update":
      """
      USAGE:
        \(executableName) update --service <service> --account <account> [options]

      OPTIONS:
        -s, --service <service>    Service name.
        -a, --account <account>    Account name.
        --stdin                    Read replacement password from stdin.
        -g, --generate             Generate replacement password automatically.
        -n, --length <length>      Generated password length.
        --force                    Skip confirmation prompt.
        -h, --help                 Show help information.

      EXAMPLES:
        \(executableName) update --service github.com --account bot@example.com --stdin
        \(executableName) update -s github.com -a bot@example.com --generate --force
      """
    case "delete":
      """
      USAGE:
        \(executableName) delete --service <service> [options]

      OPTIONS:
        -s, --service <service>    Service name.
        -a, --account <account>    Account name for single delete.
        --all-accounts             Delete all accounts under a service.
        --force                    Skip confirmation prompt.
        -h, --help                 Show help information.

      EXAMPLES:
        \(executableName) delete --service github.com --account bot@example.com
        \(executableName) delete --service github.com --all-accounts --force
      """
    case "generate":
      """
      USAGE:
        \(executableName) generate [options]

      OPTIONS:
        -n, --length <length>      Password length.
        -c, --count <count>        Number of passwords to generate.
        --no-uppercase             Exclude uppercase characters.
        --no-lowercase             Exclude lowercase characters.
        --no-digits                Exclude digits.
        --no-symbols               Exclude symbols.
        --clipboard                Copy output to clipboard.
        -h, --help                 Show help information.

      EXAMPLES:
        \(executableName) generate --length 48
        \(executableName) generate --count 3 --no-symbols
      """
    default:
      nil
    }
  }

  static func normalizedExecutableName(_ argument: String?) -> String {
    guard let argument else {
      return "applpass"
    }

    return URL(fileURLWithPath: argument).lastPathComponent
  }

  static func loadVersionFromPackage(defaultValue: String) -> String {
    for packagePath in packageManifestCandidates() {
      guard
        let contents = try? String(contentsOfFile: packagePath, encoding: .utf8),
        let version = packageVersion(in: contents)
      else {
        continue
      }

      return version
    }

    return defaultValue
  }

  private static func packageManifestCandidates() -> [String] {
    let currentDirectoryPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Package.swift")
      .path
    let sourceTreePath = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Package.swift")
      .path

    return [currentDirectoryPath, sourceTreePath]
  }

  private static func packageVersion(in packageContents: String) -> String? {
    let prefix = "let applPassVersion = \""
    guard let start = packageContents.range(of: prefix) else {
      return nil
    }

    let remainder = packageContents[start.upperBound...]
    guard let endQuote = remainder.firstIndex(of: "\"") else {
      return nil
    }

    return String(remainder[..<endQuote])
  }

  mutating func run() throws {
    let executableName = Self.normalizedExecutableName(CommandLine.arguments.first)
    var arguments = Array(CommandLine.arguments.dropFirst())

    guard let firstArgument = arguments.first else {
      print(Self.rootHelpText(executableName: executableName))
      return
    }

    if Self.isHelpRequest(firstArgument) {
      print(Self.rootHelpText(executableName: executableName))
      return
    }

    if firstArgument == "help" {
      let maybeSubcommand = arguments.dropFirst().first
      if
        let maybeSubcommand,
        let helpText = Self.subcommandHelpText(
          for: maybeSubcommand,
          executableName: executableName
        )
      {
        print(helpText)
      } else {
        print(Self.rootHelpText(executableName: executableName))
      }
      return
    }

    let subcommand = arguments.removeFirst()
    guard Self.supportedSubcommands.contains(subcommand) else {
      throw ApplPassCommandError.unknownSubcommand(subcommand)
    }

    if arguments.contains(where: Self.isHelpRequest) {
      if let helpText = Self.subcommandHelpText(for: subcommand, executableName: executableName) {
        print(helpText)
        return
      }

      throw ApplPassCommandError.missingSubcommand
    }

    switch subcommand {
    case "add":
      var command = try AddCommand.parse(arguments: arguments)
      try command.run()
    case "delete":
      var command = try DeleteCommand.parse(arguments: arguments)
      try command.run()
    case "generate":
      var command = try GenerateCommand.parse(arguments: arguments)
      try command.run()
    case "get":
      var command = try GetCommand.parse(arguments: arguments)
      try command.run()
    case "list":
      var command = try ListCommand.parse(arguments: arguments)
      try command.run()
    case "update":
      var command = try UpdateCommand.parse(arguments: arguments)
      try command.run()
    default:
      throw ApplPassCommandError.unknownSubcommand(subcommand)
    }
  }

  private static func isHelpRequest(_ argument: String) -> Bool {
    argument == "-h" || argument == "--help"
  }
}

enum ApplPassCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingSubcommand
  case unknownSubcommand(String)

  var description: String {
    let availableCommands = ApplPass.supportedSubcommands.joined(separator: ", ")

    switch self {
    case .missingSubcommand:
      return "Missing command. Available commands: \(availableCommands)."
    case .unknownSubcommand(let name):
      return "Unknown command '\(name)'. Available commands: \(availableCommands)."
    }
  }
}
