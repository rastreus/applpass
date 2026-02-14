import Foundation
import Testing

@testable import ApplPass

@Suite("Generate Command Parsing Tests")
struct GenerateCommandParsingTests {
  @Test("parse maps long options and flags")
  func parseMapsLongOptionsAndFlags() throws {
    let command = try GenerateCommand.parse(arguments: [
      "--length", "48",
      "--count", "3",
      "--no-uppercase",
      "--no-lowercase",
      "--no-digits",
      "--no-symbols",
      "--clipboard",
    ])

    #expect(command.length == 48)
    #expect(command.count == 3)
    #expect(command.noUppercase == true)
    #expect(command.noLowercase == true)
    #expect(command.noDigits == true)
    #expect(command.noSymbols == true)
    #expect(command.clipboard == true)
  }

  @Test("parse maps short options")
  func parseMapsShortOptions() throws {
    let command = try GenerateCommand.parse(arguments: [
      "-n", "64",
      "-c", "2",
    ])

    #expect(command.length == 64)
    #expect(command.count == 2)
    #expect(command.noUppercase == false)
    #expect(command.noLowercase == false)
    #expect(command.noDigits == false)
    #expect(command.noSymbols == false)
    #expect(command.clipboard == false)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try GenerateCommand.parse(arguments: [
      "--length=40",
      "--count=5",
      "--no-symbols",
    ])

    #expect(command.length == 40)
    #expect(command.count == 5)
    #expect(command.noSymbols == true)
  }

  @Test("parse rejects unknown arguments")
  func parseRejectsUnknownArguments() {
    #expect(throws: GenerateCommandError.unknownArgument("--bad-flag")) {
      _ = try GenerateCommand.parse(arguments: ["--bad-flag"])
    }
  }

  @Test("parse rejects invalid numeric options")
  func parseRejectsInvalidNumericOptions() {
    #expect(throws: GenerateCommandError.invalidOptionValue(option: "--length", value: "0")) {
      _ = try GenerateCommand.parse(arguments: ["--length", "0"])
    }

    #expect(throws: GenerateCommandError.invalidOptionValue(option: "--count", value: "zero")) {
      _ = try GenerateCommand.parse(arguments: ["--count", "zero"])
    }
  }
}

@Suite("Generate Command Behavior Tests")
struct GenerateCommandBehaviorTests {
  @Test(
    "run maps no-* flags to PasswordGenerator include booleans",
    arguments: [
      (false, false, false, false, true, true, true, true),
      (true, false, false, false, false, true, true, true),
      (false, true, false, false, true, false, true, true),
      (false, false, true, false, true, true, false, true),
      (false, false, false, true, true, true, true, false),
    ]
  )
  func runMapsCharacterSetFlagsToGeneratorParameters(
    noUppercase: Bool,
    noLowercase: Bool,
    noDigits: Bool,
    noSymbols: Bool,
    includeUppercase: Bool,
    includeLowercase: Bool,
    includeDigits: Bool,
    includeSymbols: Bool
  ) throws {
    let capturedSettings = SendableBox<(Bool, Bool, Bool, Bool)?>(nil)

    var command = GenerateCommand(
      length: 24,
      count: 1,
      noUppercase: noUppercase,
      noLowercase: noLowercase,
      noDigits: noDigits,
      noSymbols: noSymbols,
      clipboard: false,
      generatePassword: {
        _,
        generatedSymbols,
        generatedUppercase,
        generatedLowercase,
        generatedDigits in
        capturedSettings.value = (
          generatedUppercase,
          generatedLowercase,
          generatedDigits,
          generatedSymbols
        )
        return "generated-value"
      },
      output: { _ in
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard path should not be used.")
      }
    )

    try command.run()

    #expect(capturedSettings.value?.0 == includeUppercase)
    #expect(capturedSettings.value?.1 == includeLowercase)
    #expect(capturedSettings.value?.2 == includeDigits)
    #expect(capturedSettings.value?.3 == includeSymbols)
  }

  @Test("run generates multiple passwords when count is greater than one")
  func runGeneratesMultiplePasswordsForCount() throws {
    let generationCalls = SendableBox(0)
    let capturedOutput = SendableBox("")

    var command = GenerateCommand(
      length: 32,
      count: 3,
      noUppercase: false,
      noLowercase: false,
      noDigits: false,
      noSymbols: false,
      clipboard: false,
      generatePassword: { length, _, _, _, _ in
        #expect(length == 32)
        generationCalls.value += 1
        return "password-\(generationCalls.value)"
      },
      output: { message in
        capturedOutput.value = message
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard path should not be used.")
      }
    )

    try command.run()

    #expect(generationCalls.value == 3)
    #expect(capturedOutput.value == "password-1\npassword-2\npassword-3")
  }

  @Test("run copies generated output to clipboard when clipboard is enabled")
  func runCopiesOutputToClipboard() throws {
    let generationCalls = SendableBox(0)
    let copiedValue = SendableBox("")
    let capturedOutput = SendableBox("")

    var command = GenerateCommand(
      length: 20,
      count: 2,
      noUppercase: false,
      noLowercase: false,
      noDigits: false,
      noSymbols: false,
      clipboard: true,
      generatePassword: { _, _, _, _, _ in
        generationCalls.value += 1
        return "value-\(generationCalls.value)"
      },
      output: { message in
        capturedOutput.value = message
      },
      copyToClipboard: { value in
        copiedValue.value = value
      }
    )

    try command.run()

    #expect(copiedValue.value == "value-1\nvalue-2")
    #expect(capturedOutput.value == "value-1\nvalue-2")
  }

  @Test("run maps password generator errors to user-friendly messages")
  func runMapsPasswordGeneratorErrors() {
    var command = GenerateCommand(
      length: 32,
      count: 1,
      noUppercase: false,
      noLowercase: false,
      noDigits: false,
      noSymbols: false,
      clipboard: false,
      generatePassword: { _, _, _, _, _ in
        throw PasswordGeneratorError.noCharacterSetsEnabled
      },
      output: { _ in
        Issue.record("Output should not be produced on generation error.")
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard should not be used on generation error.")
      }
    )

    #expect(
      throws: GenerateCommandError.passwordGenerationMessage(
        "At least one character set must be enabled."
      )
    ) {
      try command.run()
    }
  }

  @Test("run maps clipboard failures to user-friendly messages")
  func runMapsClipboardFailures() {
    struct ClipboardFailure: Error {}

    var command = GenerateCommand(
      length: 32,
      count: 1,
      noUppercase: false,
      noLowercase: false,
      noDigits: false,
      noSymbols: false,
      clipboard: true,
      generatePassword: { _, _, _, _, _ in
        "generated-password"
      },
      output: { _ in
        Issue.record("Output should not be produced on clipboard error.")
      },
      copyToClipboard: { _ in
        throw ClipboardFailure()
      }
    )

    #expect(throws: GenerateCommandError.clipboardFailed) {
      try command.run()
    }
  }
}

private final class SendableBox<Value>: @unchecked Sendable {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}
