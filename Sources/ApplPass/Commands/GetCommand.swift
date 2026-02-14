import ArgumentParser
import Foundation

/// Retrieves a single password item from keychain.
struct GetCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Retrieve one password from keychain."
  )

  @Option(name: .shortAndLong, help: "Service name")
  var service: String?

  @Option(name: .shortAndLong, help: "Account name")
  var account: String?

  @Option(name: .shortAndLong, help: "Output format: table, json, csv, plain")
  var format: OutputStyle = .plain

  @Flag(name: .shortAndLong, help: "Copy password to clipboard using pbcopy.")
  var clipboard = false

  @Flag(name: [.customShort("v"), .long], help: "Output only the password value.")
  var valueOnly = false

  typealias GetPasswordFunction = @Sendable (KeychainQuery) throws -> KeychainItem
  typealias FormatFunction = @Sendable ([KeychainItem], OutputStyle, Bool) -> String
  typealias OutputFunction = @Sendable (String) -> Void
  typealias ClipboardFunction = @Sendable (String) throws -> Void

  private var getPassword: GetPasswordFunction = { query in
    try KeychainManager().getPassword(for: query)
  }
  private var formatOutput: FormatFunction = { items, style, showPasswords in
    OutputFormatter.format(items, style: style, showPasswords: showPasswords)
  }
  private var output: OutputFunction = { message in
    print(message)
  }
  private var copyToClipboard: ClipboardFunction = { value in
    try Self.copyWithPbcopy(value)
  }

  init() {}

  init(
    service: String?,
    account: String?,
    format: OutputStyle = .plain,
    clipboard: Bool = false,
    valueOnly: Bool = false,
    getPassword: @escaping GetPasswordFunction,
    formatOutput: @escaping FormatFunction,
    output: @escaping OutputFunction,
    copyToClipboard: @escaping ClipboardFunction
  ) {
    self.init()
    self.service = service
    self.account = account
    self.format = format
    self.clipboard = clipboard
    self.valueOnly = valueOnly
    self.getPassword = getPassword
    self.formatOutput = formatOutput
    self.output = output
    self.copyToClipboard = copyToClipboard
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
    let baseQuery = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 1
    )
    let itemClasses: [ItemClass] = [.internetPassword, .genericPassword]

    var item: KeychainItem?
    for itemClass in itemClasses {
      do {
        var query = baseQuery
        query.itemClass = itemClass
        item = try getPassword(query)
        break
      } catch let error as KeychainError {
        if error == .itemNotFound {
          continue
        }

        throw GetCommandError.keychainMessage(
          error.errorDescription ?? "Failed to retrieve password."
        )
      } catch {
        throw GetCommandError.keychainMessage("Failed to retrieve password.")
      }
    }

    guard let item else {
      throw GetCommandError.keychainMessage(
        KeychainError.itemNotFound.errorDescription ?? "Failed to retrieve password."
      )
    }

    if clipboard {
      do {
        try copyToClipboard(item.password)
      } catch {
        throw GetCommandError.clipboardFailed
      }

      output("Password copied to clipboard.")
      return
    }

    if valueOnly {
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

  private static func copyWithPbcopy(_ value: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
    let inputPipe = Pipe()
    process.standardInput = inputPipe

    do {
      try process.run()
    } catch {
      throw GetCommandError.clipboardFailed
    }

    guard let data = value.data(using: .utf8) else {
      inputPipe.fileHandleForWriting.closeFile()
      process.terminate()
      throw GetCommandError.clipboardFailed
    }

    inputPipe.fileHandleForWriting.write(data)
    inputPipe.fileHandleForWriting.closeFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw GetCommandError.clipboardFailed
    }
  }
}

enum GetCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingRequiredOption(String)
  case missingOptionValue(String)
  case invalidOptionValue(option: String, value: String)
  case unknownArgument(String)
  case keychainMessage(String)
  case clipboardFailed

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
    case .clipboardFailed:
      return "Failed to copy password to clipboard."
    }
  }
}
