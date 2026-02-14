import ArgumentParser
import Darwin
import Foundation

/// Deletes password items from keychain.
struct DeleteCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Delete a password from keychain."
  )

  @Option(name: .shortAndLong, help: "Service name")
  var service: String?

  @Option(name: .shortAndLong, help: "Account name")
  var account: String?

  @Flag(name: .long, help: "Skip delete confirmation prompt.")
  var force = false

  @Flag(name: .long, help: "Delete all accounts for the specified service.")
  var allAccounts = false

  typealias DeletePasswordFunction = @Sendable (KeychainQuery) throws -> Void
  typealias ListPasswordsFunction = @Sendable (KeychainQuery, Bool) throws -> [KeychainItem]
  typealias ConfirmDeleteFunction = @Sendable (String) throws -> Bool
  typealias OutputFunction = @Sendable (String) -> Void

  private var deletePassword: DeletePasswordFunction = { query in
    try KeychainManager().deletePassword(for: query)
  }
  private var listPasswords: ListPasswordsFunction = { query, includePasswordData in
    try KeychainManager().listPasswords(
      matching: query,
      includePasswordData: includePasswordData
    )
  }
  private var confirmDelete: ConfirmDeleteFunction = { prompt in
    try Self.promptForConfirmation(prompt: prompt)
  }
  private var output: OutputFunction = { message in
    print(message)
  }

  init() {}

  init(
    service: String?,
    account: String?,
    force: Bool,
    allAccounts: Bool,
    deletePassword: @escaping DeletePasswordFunction,
    listPasswords: @escaping ListPasswordsFunction,
    confirmDelete: @escaping ConfirmDeleteFunction,
    output: @escaping OutputFunction
  ) {
    self.init()
    self.service = service
    self.account = account
    self.force = force
    self.allAccounts = allAccounts
    self.deletePassword = deletePassword
    self.listPasswords = listPasswords
    self.confirmDelete = confirmDelete
    self.output = output
  }

  static func parse(arguments: [String]) throws -> DeleteCommand {
    var command = DeleteCommand()
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
      case "--force":
        command.force = true
      case "--all-accounts":
        command.allAccounts = true
      default:
        if argument.hasPrefix("--service=") {
          command.service = String(argument.dropFirst("--service=".count))
        } else if argument.hasPrefix("--account=") {
          command.account = String(argument.dropFirst("--account=".count))
        } else {
          throw DeleteCommandError.unknownArgument(argument)
        }
      }

      index += 1
    }

    return command
  }

  mutating func run() throws {
    let service = try requiredValue(service, option: "--service")

    if allAccounts {
      let providedAccount = Self.normalizedValue(account)
      if providedAccount != nil {
        throw DeleteCommandError.conflictingOptions(
          "--account cannot be used with --all-accounts."
        )
      }

      try deleteAllAccounts(for: service)
      return
    }

    let account = try requiredValue(account, option: "--account")
    output("Will delete password for service '\(service)' and account '\(account)'.")

    if !force {
      let prompt = "Delete password for service '\(service)' and account '\(account)'? [y/N]: "
      let confirmed = try confirmDeletion(with: prompt)
      guard confirmed else {
        output("Delete cancelled.")
        return
      }
    }

    do {
      try deletePassword(Self.deletionQuery(service: service, account: account))
    } catch let error as KeychainError {
      throw DeleteCommandError.keychainMessage(
        error.errorDescription ?? "Failed to delete password."
      )
    } catch {
      throw DeleteCommandError.keychainMessage("Failed to delete password.")
    }

    output("Deleted password for service '\(service)' and account '\(account)'.")
  }

  private mutating func deleteAllAccounts(for service: String) throws {
    let listQuery = KeychainQuery(
      service: service,
      account: nil,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 100
    )

    let items: [KeychainItem]
    do {
      items = try listPasswords(listQuery, false)
    } catch let error as KeychainError {
      throw DeleteCommandError.keychainMessage(
        error.errorDescription ?? "Failed to load passwords for deletion."
      )
    } catch {
      throw DeleteCommandError.keychainMessage("Failed to load passwords for deletion.")
    }

    let accounts = Set(items.map(\.account)).sorted()

    guard !accounts.isEmpty else {
      output("No passwords found for service '\(service)'.")
      return
    }

    output("Will delete \(accounts.count) password(s) for service '\(service)':")
    for account in accounts {
      output("- \(account)")
    }

    if !force {
      let prompt = "Delete all passwords for service '\(service)'? [y/N]: "
      let confirmed = try confirmDeletion(with: prompt)
      guard confirmed else {
        output("Delete cancelled.")
        return
      }
    }

    do {
      for account in accounts {
        try deletePassword(Self.deletionQuery(service: service, account: account))
      }
    } catch let error as KeychainError {
      throw DeleteCommandError.keychainMessage(
        error.errorDescription ?? "Failed to delete password."
      )
    } catch {
      throw DeleteCommandError.keychainMessage("Failed to delete password.")
    }

    output("Deleted \(accounts.count) password(s) for service '\(service)'.")
  }

  private mutating func confirmDeletion(with prompt: String) throws -> Bool {
    do {
      return try confirmDelete(prompt)
    } catch let error as DeleteCommandError {
      throw error
    } catch {
      throw DeleteCommandError.confirmationInputFailed
    }
  }

  private static func value(
    after option: String,
    in arguments: [String],
    at index: Int
  ) throws -> String {
    let nextIndex = index + 1
    guard nextIndex < arguments.count else {
      throw DeleteCommandError.missingOptionValue(option)
    }

    let value = arguments[nextIndex]
    guard !value.hasPrefix("-") else {
      throw DeleteCommandError.missingOptionValue(option)
    }

    return value
  }

  private func requiredValue(_ value: String?, option: String) throws -> String {
    guard let value = Self.normalizedValue(value) else {
      throw DeleteCommandError.missingRequiredOption(option)
    }

    return value
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

  private static func deletionQuery(service: String, account: String) -> KeychainQuery {
    KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 1
    )
  }

  private static func promptForConfirmation(prompt: String) throws -> Bool {
    guard isatty(STDIN_FILENO) == 1 else {
      throw DeleteCommandError.confirmationPromptRequiresTTY
    }

    if let data = prompt.data(using: .utf8) {
      FileHandle.standardError.write(data)
    }

    guard let answer = readLine(strippingNewline: true) else {
      throw DeleteCommandError.confirmationInputFailed
    }

    let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "y" || normalized == "yes"
  }
}

enum DeleteCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingRequiredOption(String)
  case missingOptionValue(String)
  case unknownArgument(String)
  case conflictingOptions(String)
  case confirmationPromptRequiresTTY
  case confirmationInputFailed
  case keychainMessage(String)

  var description: String {
    switch self {
    case .missingRequiredOption(let option):
      return "Missing required option: \(option)."
    case .missingOptionValue(let option):
      return "Missing value for option: \(option)."
    case .unknownArgument(let argument):
      return "Unknown argument: \(argument)."
    case .conflictingOptions(let message):
      return message
    case .confirmationPromptRequiresTTY:
      return "Interactive confirmation requires a TTY. Use --force to skip confirmation."
    case .confirmationInputFailed:
      return "Failed to read confirmation input."
    case .keychainMessage(let message):
      return message
    }
  }
}
