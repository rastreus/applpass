import ArgumentParser
import Darwin
import Foundation

/// Updates an existing password item in keychain.
struct UpdateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Update a password in keychain."
  )

  @Option(name: .shortAndLong, help: "Service name")
  var service: String?

  @Option(name: .shortAndLong, help: "Account name")
  var account: String?

  @Flag(name: .long, help: "Read the new password from stdin.")
  var stdin = false

  @Flag(name: .shortAndLong, help: "Generate a random new password.")
  var generate = false

  @Flag(name: .long, help: "Skip update confirmation prompt.")
  var force = false

  @Option(name: .long, help: "Generated password length.")
  var length = 32

  typealias UpdatePasswordFunction = @Sendable (KeychainQuery, String) throws -> Void
  typealias GeneratePasswordFunction = @Sendable (Int) throws -> String
  typealias ReadLineFunction = @Sendable () -> String?
  typealias PromptPasswordFunction = @Sendable () throws -> String
  typealias ConfirmUpdateFunction = @Sendable (String, String) throws -> Bool
  typealias OutputFunction = @Sendable (String) -> Void

  private var updatePassword: UpdatePasswordFunction = { query, password in
    try PasswordStoreFactory.make().updatePassword(for: query, newPassword: password)
  }
  private var generatePassword: GeneratePasswordFunction = { length in
    try PasswordGenerator.generate(length: length)
  }
  private var readStdinLine: ReadLineFunction = {
    readLine(strippingNewline: true)
  }
  private var promptPassword: PromptPasswordFunction = {
    try Self.readPasswordInteractively(prompt: "Enter new password: ")
  }
  private var confirmUpdate: ConfirmUpdateFunction = { service, account in
    try Self.promptForConfirmation(service: service, account: account)
  }
  private var output: OutputFunction = { message in
    print(message)
  }

  init() {}

  init(
    service: String?,
    account: String?,
    stdin: Bool,
    generate: Bool,
    force: Bool,
    length: Int = 32,
    updatePassword: @escaping UpdatePasswordFunction,
    generatePassword: @escaping GeneratePasswordFunction,
    readStdinLine: @escaping ReadLineFunction,
    promptPassword: @escaping PromptPasswordFunction,
    confirmUpdate: @escaping ConfirmUpdateFunction,
    output: @escaping OutputFunction
  ) {
    self.init()
    self.service = service
    self.account = account
    self.stdin = stdin
    self.generate = generate
    self.force = force
    self.length = length
    self.updatePassword = updatePassword
    self.generatePassword = generatePassword
    self.readStdinLine = readStdinLine
    self.promptPassword = promptPassword
    self.confirmUpdate = confirmUpdate
    self.output = output
  }

  static func parse(arguments: [String]) throws -> UpdateCommand {
    var command = UpdateCommand()
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
      case "-n", "--length":
        let value = try value(after: argument, in: arguments, at: index)
        command.length = try parsedLength(from: value)
        index += 1
      case "--stdin":
        command.stdin = true
      case "-g", "--generate":
        command.generate = true
      case "--force":
        command.force = true
      default:
        if argument.hasPrefix("--service=") {
          command.service = String(argument.dropFirst("--service=".count))
        } else if argument.hasPrefix("--account=") {
          command.account = String(argument.dropFirst("--account=".count))
        } else if argument.hasPrefix("--length=") {
          let value = String(argument.dropFirst("--length=".count))
          command.length = try parsedLength(from: value)
        } else {
          throw UpdateCommandError.unknownArgument(argument)
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
      throw UpdateCommandError.conflictingInputModes
    }

    let password = try resolvedPassword()
    guard !password.isEmpty else {
      throw UpdateCommandError.emptyPasswordInput
    }

    if !force {
      let shouldProceed: Bool
      do {
        shouldProceed = try confirmUpdate(service, account)
      } catch let error as UpdateCommandError {
        throw error
      } catch {
        throw UpdateCommandError.confirmationInputFailed
      }

      guard shouldProceed else {
        output("Update cancelled.")
        return
      }
    }

    let query = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 1
    )

    do {
      try updatePassword(query, password)
    } catch let error as KeychainError {
      throw UpdateCommandError.keychainMessage(
        error.errorDescription ?? "Failed to update password."
      )
    } catch {
      throw UpdateCommandError.keychainMessage("Failed to update password.")
    }

    output("Updated password for service '\(service)' and account '\(account)'.")
  }

  private mutating func resolvedPassword() throws -> String {
    if generate {
      do {
        return try generatePassword(length)
      } catch let error as PasswordGeneratorError {
        throw UpdateCommandError.passwordGenerationMessage(
          error.errorDescription ?? "Failed to generate password."
        )
      } catch {
        throw UpdateCommandError.passwordGenerationMessage("Failed to generate password.")
      }
    }

    if stdin {
      guard let value = readStdinLine() else {
        throw UpdateCommandError.passwordInputFailed
      }

      return value
    }

    do {
      return try promptPassword()
    } catch let error as UpdateCommandError {
      throw error
    } catch {
      throw UpdateCommandError.passwordInputFailed
    }
  }

  private static func value(
    after option: String,
    in arguments: [String],
    at index: Int
  ) throws -> String {
    let nextIndex = index + 1
    guard nextIndex < arguments.count else {
      throw UpdateCommandError.missingOptionValue(option)
    }

    let value = arguments[nextIndex]
    guard !value.hasPrefix("-") else {
      throw UpdateCommandError.missingOptionValue(option)
    }

    return value
  }

  private static func parsedLength(from value: String) throws -> Int {
    guard let length = Int(value), length > 0 else {
      throw UpdateCommandError.invalidOptionValue(option: "--length", value: value)
    }

    return length
  }

  private func requiredValue(
    _ value: String?,
    option: String
  ) throws -> String {
    guard let value else {
      throw UpdateCommandError.missingRequiredOption(option)
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw UpdateCommandError.missingRequiredOption(option)
    }

    return trimmed
  }

  private static func readPasswordInteractively(prompt: String) throws -> String {
    guard isatty(STDIN_FILENO) == 1 else {
      throw UpdateCommandError.passwordPromptRequiresTTY
    }

    if let data = prompt.data(using: .utf8) {
      FileHandle.standardError.write(data)
    }

    var terminalSettings = termios()
    guard tcgetattr(STDIN_FILENO, &terminalSettings) == 0 else {
      throw UpdateCommandError.passwordInputFailed
    }

    let originalSettings = terminalSettings
    terminalSettings.c_lflag &= ~tcflag_t(ECHO)

    guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &terminalSettings) == 0 else {
      throw UpdateCommandError.passwordInputFailed
    }

    defer {
      var restored = originalSettings
      _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &restored)
      FileHandle.standardError.write(Data("\n".utf8))
    }

    guard let password = readLine(strippingNewline: true) else {
      throw UpdateCommandError.passwordInputFailed
    }

    return password
  }

  private static func promptForConfirmation(
    service: String,
    account: String
  ) throws -> Bool {
    guard isatty(STDIN_FILENO) == 1 else {
      throw UpdateCommandError.confirmationPromptRequiresTTY
    }

    let prompt = "Update password for service '\(service)' and account '\(account)'? [y/N]: "
    if let data = prompt.data(using: .utf8) {
      FileHandle.standardError.write(data)
    }

    guard let answer = readLine(strippingNewline: true) else {
      throw UpdateCommandError.confirmationInputFailed
    }

    let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "y" || normalized == "yes"
  }
}

enum UpdateCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingRequiredOption(String)
  case missingOptionValue(String)
  case invalidOptionValue(option: String, value: String)
  case unknownArgument(String)
  case conflictingInputModes
  case emptyPasswordInput
  case passwordPromptRequiresTTY
  case passwordInputFailed
  case confirmationPromptRequiresTTY
  case confirmationInputFailed
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
    case .confirmationPromptRequiresTTY:
      return "Interactive confirmation requires a TTY. Use --force to skip confirmation."
    case .confirmationInputFailed:
      return "Failed to read confirmation input."
    case .passwordGenerationMessage(let message):
      return message
    case .keychainMessage(let message):
      return message
    }
  }
}
