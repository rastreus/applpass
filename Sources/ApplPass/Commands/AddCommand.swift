import ArgumentParser
import Darwin
import Foundation

/// Adds a password item to keychain.
struct AddCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Add a password to keychain."
  )

  @Option(name: .shortAndLong, help: "Service name")
  var service: String?

  @Option(name: .shortAndLong, help: "Account name")
  var account: String?

  @Option(name: .shortAndLong, help: "Optional keychain item label")
  var label: String?

  @Flag(name: .long, help: "Read password from stdin.")
  var stdin = false

  @Flag(name: .shortAndLong, help: "Generate a random password.")
  var generate = false

  @Flag(name: .long, help: "Synchronize password through iCloud keychain.")
  var sync = false

  @Option(name: .long, help: "Generated password length.")
  var length = 32

  typealias AddPasswordFunction = @Sendable (String, String, String, String, Bool) throws -> Void
  typealias GeneratePasswordFunction = @Sendable (Int) throws -> String
  typealias ReadLineFunction = @Sendable () -> String?
  typealias PromptPasswordFunction = @Sendable () throws -> String
  typealias OutputFunction = @Sendable (String) -> Void

  private var addPassword: AddPasswordFunction = { service, account, password, label, sync in
    try PasswordStoreFactory.make().addPassword(
      service: service,
      account: account,
      password: password,
      label: label,
      sync: sync
    )
  }
  private var generatePassword: GeneratePasswordFunction = { length in
    try PasswordGenerator.generate(length: length)
  }
  private var readStdinLine: ReadLineFunction = {
    readLine(strippingNewline: true)
  }
  private var promptPassword: PromptPasswordFunction = {
    try Self.readPasswordInteractively(prompt: "Enter password: ")
  }
  private var output: OutputFunction = { message in
    print(message)
  }

  init() {}

  init(
    service: String?,
    account: String?,
    label: String?,
    stdin: Bool,
    generate: Bool,
    sync: Bool,
    length: Int = 32,
    addPassword: @escaping AddPasswordFunction,
    generatePassword: @escaping GeneratePasswordFunction,
    readStdinLine: @escaping ReadLineFunction,
    promptPassword: @escaping PromptPasswordFunction,
    output: @escaping OutputFunction
  ) {
    self.init()
    self.service = service
    self.account = account
    self.label = label
    self.stdin = stdin
    self.generate = generate
    self.sync = sync
    self.length = length
    self.addPassword = addPassword
    self.generatePassword = generatePassword
    self.readStdinLine = readStdinLine
    self.promptPassword = promptPassword
    self.output = output
  }

  static func parse(arguments: [String]) throws -> AddCommand {
    var command = AddCommand()
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
      case "-l", "--label":
        command.label = try value(after: argument, in: arguments, at: index)
        index += 1
      case "-n", "--length":
        let value = try value(after: argument, in: arguments, at: index)
        command.length = try parsedLength(from: value)
        index += 1
      case "--stdin":
        command.stdin = true
      case "-g", "--generate":
        command.generate = true
      case "--sync":
        command.sync = true
      default:
        if argument.hasPrefix("--service=") {
          command.service = String(argument.dropFirst("--service=".count))
        } else if argument.hasPrefix("--account=") {
          command.account = String(argument.dropFirst("--account=".count))
        } else if argument.hasPrefix("--label=") {
          command.label = String(argument.dropFirst("--label=".count))
        } else if argument.hasPrefix("--length=") {
          let value = String(argument.dropFirst("--length=".count))
          command.length = try parsedLength(from: value)
        } else {
          throw AddCommandError.unknownArgument(argument)
        }
      }

      index += 1
    }

    return command
  }

  mutating func run() throws {
    let service = try requiredValue(service, option: "--service")
    let account = try requiredValue(account, option: "--account")

    if stdin && generate {
      throw AddCommandError.conflictingInputModes
    }

    let label = Self.normalizedLabel(label, fallbackService: service)
    let password = try resolvedPassword()

    guard !password.isEmpty else {
      throw AddCommandError.emptyPasswordInput
    }

    do {
      try addPassword(service, account, password, label, sync)
    } catch let error as KeychainError {
      throw AddCommandError.keychainMessage(error.errorDescription ?? "Failed to add password.")
    } catch {
      throw AddCommandError.keychainMessage("Failed to add password.")
    }

    output("Added password for service '\(service)' and account '\(account)'.")
  }

  private mutating func resolvedPassword() throws -> String {
    if generate {
      do {
        return try generatePassword(length)
      } catch let error as PasswordGeneratorError {
        throw AddCommandError.passwordGenerationMessage(
          error.errorDescription ?? "Failed to generate password."
        )
      } catch {
        throw AddCommandError.passwordGenerationMessage("Failed to generate password.")
      }
    }

    if stdin {
      guard let value = readStdinLine() else {
        throw AddCommandError.passwordInputFailed
      }

      return value
    }

    do {
      return try promptPassword()
    } catch let error as AddCommandError {
      throw error
    } catch {
      throw AddCommandError.passwordInputFailed
    }
  }

  private static func value(
    after option: String,
    in arguments: [String],
    at index: Int
  ) throws -> String {
    let nextIndex = index + 1
    guard nextIndex < arguments.count else {
      throw AddCommandError.missingOptionValue(option)
    }

    let value = arguments[nextIndex]
    guard !value.hasPrefix("-") else {
      throw AddCommandError.missingOptionValue(option)
    }

    return value
  }

  private static func parsedLength(from value: String) throws -> Int {
    guard let length = Int(value), length > 0 else {
      throw AddCommandError.invalidOptionValue(option: "--length", value: value)
    }

    return length
  }

  private func requiredValue(
    _ value: String?,
    option: String
  ) throws -> String {
    guard let value else {
      throw AddCommandError.missingRequiredOption(option)
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw AddCommandError.missingRequiredOption(option)
    }

    return trimmed
  }

  private static func normalizedLabel(_ label: String?, fallbackService: String) -> String {
    guard let label else {
      return fallbackService
    }

    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return fallbackService
    }

    return trimmed
  }

  private static func readPasswordInteractively(prompt: String) throws -> String {
    guard isatty(STDIN_FILENO) == 1 else {
      throw AddCommandError.passwordPromptRequiresTTY
    }

    if let data = prompt.data(using: .utf8) {
      FileHandle.standardError.write(data)
    }

    var terminalSettings = termios()
    guard tcgetattr(STDIN_FILENO, &terminalSettings) == 0 else {
      throw AddCommandError.passwordInputFailed
    }

    let originalSettings = terminalSettings
    terminalSettings.c_lflag &= ~tcflag_t(ECHO)

    guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &terminalSettings) == 0 else {
      throw AddCommandError.passwordInputFailed
    }

    defer {
      var restored = originalSettings
      _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &restored)
      FileHandle.standardError.write(Data("\n".utf8))
    }

    guard let password = readLine(strippingNewline: true) else {
      throw AddCommandError.passwordInputFailed
    }

    return password
  }
}

enum AddCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingRequiredOption(String)
  case missingOptionValue(String)
  case invalidOptionValue(option: String, value: String)
  case unknownArgument(String)
  case conflictingInputModes
  case emptyPasswordInput
  case passwordPromptRequiresTTY
  case passwordInputFailed
  case passwordGenerationMessage(String)
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
    case .conflictingInputModes:
      return "--stdin and --generate cannot be used together."
    case .emptyPasswordInput:
      return "Password cannot be empty."
    case .passwordPromptRequiresTTY:
      return "Interactive password entry requires a TTY. Use --stdin or --generate."
    case .passwordInputFailed:
      return "Failed to read password input."
    case .passwordGenerationMessage(let message):
      return message
    case .keychainMessage(let message):
      return message
    }
  }
}
