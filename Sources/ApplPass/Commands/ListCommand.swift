import ArgumentParser
import Foundation

/// Retrieves multiple password items from keychain.
struct ListCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "List passwords from keychain."
  )

  @Option(name: .shortAndLong, help: "Filter by service name")
  var service: String?

  @Option(name: .shortAndLong, help: "Filter by account name")
  var account: String?

  @Option(name: .shortAndLong, help: "Filter by substring in service/account/group")
  var search: String?

  @Option(name: .shortAndLong, help: "Output format: table, json, csv, plain")
  var format: OutputStyle = .table

  @Flag(name: .long, help: "Show only shared-password items.")
  var sharedOnly = false

  @Flag(name: .long, help: "Show only personal (non-shared) items.")
  var personalOnly = false

  @Flag(name: .long, help: "Include password values in output.")
  var showPasswords = false

  typealias ListPasswordsFunction = @Sendable (KeychainQuery, Bool) throws -> [KeychainItem]
  typealias FormatFunction = @Sendable ([KeychainItem], OutputStyle, Bool) -> String
  typealias OutputFunction = @Sendable (String) -> Void

  private var listPasswords: ListPasswordsFunction = { query, includePasswordData in
    try KeychainManager().listPasswords(
      matching: query,
      includePasswordData: includePasswordData
    )
  }
  private var formatOutput: FormatFunction = { items, style, showPasswords in
    OutputFormatter.format(items, style: style, showPasswords: showPasswords)
  }
  private var output: OutputFunction = { message in
    print(message)
  }

  init() {}

  init(
    service: String?,
    account: String?,
    search: String?,
    format: OutputStyle = .table,
    sharedOnly: Bool = false,
    personalOnly: Bool = false,
    showPasswords: Bool = false,
    listPasswords: @escaping ListPasswordsFunction,
    formatOutput: @escaping FormatFunction,
    output: @escaping OutputFunction
  ) {
    self.init()
    self.service = service
    self.account = account
    self.search = search
    self.format = format
    self.sharedOnly = sharedOnly
    self.personalOnly = personalOnly
    self.showPasswords = showPasswords
    self.listPasswords = listPasswords
    self.formatOutput = formatOutput
    self.output = output
  }

  static func parse(arguments: [String]) throws -> ListCommand {
    var command = ListCommand()
    var index = 0

    while index < arguments.count {
      let argument = arguments[index]

      switch argument {
      case "-s", "--service":
        command.service = try value(after: argument, in: arguments, at: index)
        index += 1
      case "-a", "--account":
        command.account = try value(after: argument, in: arguments, at: index)
        index += 1
      case "-q", "--search":
        command.search = try value(after: argument, in: arguments, at: index)
        index += 1
      case "-f", "--format":
        let value = try value(after: argument, in: arguments, at: index)
        command.format = try outputStyle(from: value)
        index += 1
      case "--shared-only":
        command.sharedOnly = true
      case "--personal-only":
        command.personalOnly = true
      case "--show-passwords":
        command.showPasswords = true
      default:
        if argument.hasPrefix("--service=") {
          command.service = String(argument.dropFirst("--service=".count))
        } else if argument.hasPrefix("--account=") {
          command.account = String(argument.dropFirst("--account=".count))
        } else if argument.hasPrefix("--search=") {
          command.search = String(argument.dropFirst("--search=".count))
        } else if argument.hasPrefix("--format=") {
          let value = String(argument.dropFirst("--format=".count))
          command.format = try outputStyle(from: value)
        } else {
          throw ListCommandError.unknownArgument(argument)
        }
      }

      index += 1
    }

    return command
  }

  mutating func run() throws {
    let query = KeychainQuery(
      service: Self.normalizedValue(service),
      account: Self.normalizedValue(account),
      domain: nil,
      includeShared: !personalOnly,
      itemClass: .genericPassword,
      limit: 100
    )

    let items: [KeychainItem]
    do {
      items = try listPasswords(query, showPasswords)
    } catch let error as KeychainError {
      throw ListCommandError.keychainMessage(
        error.errorDescription ?? "Failed to list passwords."
      )
    } catch {
      throw ListCommandError.keychainMessage("Failed to list passwords.")
    }

    let filteredItems = Self.filteredItems(
      items,
      search: search,
      sharedOnly: sharedOnly,
      personalOnly: personalOnly
    )
    let rendered = formatOutput(filteredItems, format, showPasswords)
    output(rendered)
  }

  static func filteredItems(
    _ items: [KeychainItem],
    search: String?,
    sharedOnly: Bool,
    personalOnly: Bool
  ) -> [KeychainItem] {
    var filtered = items

    if sharedOnly {
      filtered = filtered.filter(\.isShared)
    }

    if personalOnly {
      filtered = filtered.filter { !$0.isShared }
    }

    if let search = normalizedValue(search) {
      filtered = filtered.filter { item in
        item.service.localizedCaseInsensitiveContains(search)
          || item.account.localizedCaseInsensitiveContains(search)
          || (item.sharedGroupName?.localizedCaseInsensitiveContains(search) ?? false)
      }
    }

    return filtered
  }

  private static func value(
    after option: String,
    in arguments: [String],
    at index: Int
  ) throws -> String {
    let nextIndex = index + 1
    guard nextIndex < arguments.count else {
      throw ListCommandError.missingOptionValue(option)
    }

    let value = arguments[nextIndex]
    guard !value.hasPrefix("-") else {
      throw ListCommandError.missingOptionValue(option)
    }

    return value
  }

  private static func outputStyle(from value: String) throws -> OutputStyle {
    let normalized = value.lowercased()
    guard let style = OutputStyle(rawValue: normalized) else {
      throw ListCommandError.invalidOptionValue(option: "--format", value: value)
    }

    return style
  }

  private static func normalizedValue(_ value: String?) -> String? {
    guard let value else {
      return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }

    return trimmed
  }
}

enum ListCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingOptionValue(String)
  case invalidOptionValue(option: String, value: String)
  case unknownArgument(String)
  case keychainMessage(String)

  var description: String {
    switch self {
    case .missingOptionValue(let option):
      return "Missing value for option: \(option)."
    case .invalidOptionValue(let option, let value):
      return "Invalid value '\(value)' for option \(option)."
    case .unknownArgument(let argument):
      return "Unknown argument: \(argument)."
    case .keychainMessage(let message):
      return message
    }
  }
}
