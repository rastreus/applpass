import ArgumentParser

/// Retrieves a single password item from keychain.
struct GetCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Retrieve one password from keychain."
  )

  var service: String?
  var account: String?
  var format: OutputStyle
  var clipboard: Bool
  var valueOnly: Bool

  typealias GetPasswordFunction = @Sendable (KeychainQuery) throws -> KeychainItem
  typealias FormatFunction = @Sendable ([KeychainItem], OutputStyle, Bool) -> String
  typealias OutputFunction = @Sendable (String) -> Void

  private var getPassword: GetPasswordFunction
  private var formatOutput: FormatFunction
  private var output: OutputFunction

  init() {
    self.service = nil
    self.account = nil
    self.format = .plain
    self.clipboard = false
    self.valueOnly = false
    self.getPassword = { query in
      try KeychainManager().getPassword(for: query)
    }
    self.formatOutput = { items, style, showPasswords in
      OutputFormatter.format(items, style: style, showPasswords: showPasswords)
    }
    self.output = { message in
      print(message)
    }
  }

  init(
    service: String?,
    account: String?,
    format: OutputStyle = .plain,
    clipboard: Bool = false,
    valueOnly: Bool = false,
    getPassword: @escaping GetPasswordFunction,
    formatOutput: @escaping FormatFunction,
    output: @escaping OutputFunction
  ) {
    self.service = service
    self.account = account
    self.format = format
    self.clipboard = clipboard
    self.valueOnly = valueOnly
    self.getPassword = getPassword
    self.formatOutput = formatOutput
    self.output = output
  }

  static func parse(arguments: [String]) throws -> GetCommand {
    var command = GetCommand()
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
      case "-f", "--format":
        let value = try value(after: argument, in: arguments, at: index)
        command.format = try outputStyle(from: value)
        index += 1
      case "-c", "--clipboard":
        command.clipboard = true
      case "-v", "--value-only":
        command.valueOnly = true
      default:
        if argument.hasPrefix("--service=") {
          command.service = String(argument.dropFirst("--service=".count))
        } else if argument.hasPrefix("--account=") {
          command.account = String(argument.dropFirst("--account=".count))
        } else if argument.hasPrefix("--format=") {
          let value = String(argument.dropFirst("--format=".count))
          command.format = try outputStyle(from: value)
        } else {
          throw GetCommandError.unknownArgument(argument)
        }
      }

      index += 1
    }

    return command
  }

  mutating func run() throws {
    let service = try requiredValue(service, option: "--service")
    let account = try requiredValue(account, option: "--account")
    let query = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 1
    )

    let item: KeychainItem
    do {
      item = try getPassword(query)
    } catch let error as KeychainError {
      throw GetCommandError.keychainMessage(
        error.errorDescription ?? "Failed to retrieve password."
      )
    }

    if valueOnly || clipboard {
      output(item.password)
      return
    }

    let rendered = formatOutput([item], format, true)
    output(rendered)
  }

  private static func value(
    after option: String,
    in arguments: [String],
    at index: Int
  ) throws -> String {
    let nextIndex = index + 1
    guard nextIndex < arguments.count else {
      throw GetCommandError.missingOptionValue(option)
    }

    let value = arguments[nextIndex]
    guard !value.hasPrefix("-") else {
      throw GetCommandError.missingOptionValue(option)
    }

    return value
  }

  private static func outputStyle(from value: String) throws -> OutputStyle {
    let normalized = value.lowercased()
    guard let style = OutputStyle(rawValue: normalized) else {
      throw GetCommandError.invalidOptionValue(option: "--format", value: value)
    }

    return style
  }

  private func requiredValue(
    _ value: String?,
    option: String
  ) throws -> String {
    guard let value else {
      throw GetCommandError.missingRequiredOption(option)
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw GetCommandError.missingRequiredOption(option)
    }

    return trimmed
  }
}

enum GetCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingRequiredOption(String)
  case missingOptionValue(String)
  case invalidOptionValue(option: String, value: String)
  case unknownArgument(String)
  case keychainMessage(String)

  var description: String {
    switch self {
    case .missingRequiredOption(let option):
      return "Missing required option: \(option)."
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
