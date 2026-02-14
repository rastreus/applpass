import ArgumentParser
import Foundation

/// Generates one or more passwords without storing them.
struct GenerateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Generate password values without storing in keychain."
  )

  @Option(name: .long, help: "Generated password length.")
  var length = 32

  @Option(name: .shortAndLong, help: "Number of passwords to generate.")
  var count = 1

  @Flag(name: .long, help: "Exclude uppercase characters.")
  var noUppercase = false

  @Flag(name: .long, help: "Exclude lowercase characters.")
  var noLowercase = false

  @Flag(name: .long, help: "Exclude digits.")
  var noDigits = false

  @Flag(name: .long, help: "Exclude symbols.")
  var noSymbols = false

  @Flag(name: .long, help: "Copy generated password output to clipboard using pbcopy.")
  var clipboard = false

  typealias GeneratePasswordFunction =
    @Sendable (Int, Bool, Bool, Bool, Bool) throws -> String
  typealias OutputFunction = @Sendable (String) -> Void
  typealias ClipboardFunction = @Sendable (String) throws -> Void

  private var generatePassword: GeneratePasswordFunction = {
    length,
    includeSymbols,
    includeUppercase,
    includeLowercase,
    includeDigits in
    try PasswordGenerator.generate(
      length: length,
      includeSymbols: includeSymbols,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeDigits: includeDigits
    )
  }
  private var output: OutputFunction = { message in
    print(message)
  }
  private var copyToClipboard: ClipboardFunction = { value in
    try Self.copyWithPbcopy(value)
  }

  init() {}

  init(
    length: Int = 32,
    count: Int = 1,
    noUppercase: Bool = false,
    noLowercase: Bool = false,
    noDigits: Bool = false,
    noSymbols: Bool = false,
    clipboard: Bool = false,
    generatePassword: @escaping GeneratePasswordFunction,
    output: @escaping OutputFunction,
    copyToClipboard: @escaping ClipboardFunction
  ) {
    self.init()
    self.length = length
    self.count = count
    self.noUppercase = noUppercase
    self.noLowercase = noLowercase
    self.noDigits = noDigits
    self.noSymbols = noSymbols
    self.clipboard = clipboard
    self.generatePassword = generatePassword
    self.output = output
    self.copyToClipboard = copyToClipboard
  }

  static func parse(arguments: [String]) throws -> GenerateCommand {
    var command = GenerateCommand()
    var index = 0

    while index < arguments.count {
      let argument = arguments[index]

      switch argument {
      case "-n", "--length":
        let value = try value(after: argument, in: arguments, at: index)
        command.length = try parsedPositiveInt(option: "--length", value: value)
        index += 1
      case "-c", "--count":
        let value = try value(after: argument, in: arguments, at: index)
        command.count = try parsedPositiveInt(option: "--count", value: value)
        index += 1
      case "--no-uppercase":
        command.noUppercase = true
      case "--no-lowercase":
        command.noLowercase = true
      case "--no-digits":
        command.noDigits = true
      case "--no-symbols":
        command.noSymbols = true
      case "--clipboard":
        command.clipboard = true
      default:
        if argument.hasPrefix("--length=") {
          let value = String(argument.dropFirst("--length=".count))
          command.length = try parsedPositiveInt(option: "--length", value: value)
        } else if argument.hasPrefix("--count=") {
          let value = String(argument.dropFirst("--count=".count))
          command.count = try parsedPositiveInt(option: "--count", value: value)
        } else {
          throw GenerateCommandError.unknownArgument(argument)
        }
      }

      index += 1
    }

    return command
  }

  mutating func run() throws {
    let passwords = try generatedPasswords()
    let outputValue = passwords.joined(separator: "\n")

    if clipboard {
      do {
        try copyToClipboard(outputValue)
      } catch {
        throw GenerateCommandError.clipboardFailed
      }
    }

    output(outputValue)
  }

  private func generatedPasswords() throws -> [String] {
    let includeUppercase = !noUppercase
    let includeLowercase = !noLowercase
    let includeDigits = !noDigits
    let includeSymbols = !noSymbols

    var values: [String] = []
    values.reserveCapacity(count)

    do {
      for _ in 0..<count {
        values.append(
          try generatePassword(
            length,
            includeSymbols,
            includeUppercase,
            includeLowercase,
            includeDigits
          )
        )
      }
    } catch let error as PasswordGeneratorError {
      throw GenerateCommandError.passwordGenerationMessage(
        error.errorDescription ?? "Failed to generate password."
      )
    } catch {
      throw GenerateCommandError.passwordGenerationMessage("Failed to generate password.")
    }

    return values
  }

  private static func value(
    after option: String,
    in arguments: [String],
    at index: Int
  ) throws -> String {
    let nextIndex = index + 1
    guard nextIndex < arguments.count else {
      throw GenerateCommandError.missingOptionValue(option)
    }

    let value = arguments[nextIndex]
    guard !value.hasPrefix("-") else {
      throw GenerateCommandError.missingOptionValue(option)
    }

    return value
  }

  private static func parsedPositiveInt(
    option: String,
    value: String
  ) throws -> Int {
    guard let parsed = Int(value), parsed > 0 else {
      throw GenerateCommandError.invalidOptionValue(option: option, value: value)
    }

    return parsed
  }

  private static func copyWithPbcopy(_ value: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
    let inputPipe = Pipe()
    process.standardInput = inputPipe

    do {
      try process.run()
    } catch {
      throw GenerateCommandError.clipboardFailed
    }

    guard let data = value.data(using: .utf8) else {
      inputPipe.fileHandleForWriting.closeFile()
      process.terminate()
      throw GenerateCommandError.clipboardFailed
    }

    inputPipe.fileHandleForWriting.write(data)
    inputPipe.fileHandleForWriting.closeFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw GenerateCommandError.clipboardFailed
    }
  }
}

enum GenerateCommandError: Error, Sendable, Equatable, CustomStringConvertible {
  case missingOptionValue(String)
  case invalidOptionValue(option: String, value: String)
  case unknownArgument(String)
  case passwordGenerationMessage(String)
  case clipboardFailed

  var description: String {
    switch self {
    case .missingOptionValue(let option):
      return "Missing value for option: \(option)."
    case .invalidOptionValue(let option, let value):
      return "Invalid value '\(value)' for option \(option)."
    case .unknownArgument(let argument):
      return "Unknown argument: \(argument)."
    case .passwordGenerationMessage(let message):
      return message
    case .clipboardFailed:
      return "Failed to copy generated password to clipboard."
    }
  }
}
