import Testing
@testable import ApplPass

@Suite("Update Command Parsing Tests")
struct UpdateCommandParsingTests {
  @Test("parse maps long options and flags")
  func parseMapsLongOptionsAndFlags() throws {
    let command = try UpdateCommand.parse(arguments: [
      "--service", "github.com",
      "--account", "bot@example.com",
      "--stdin",
      "--generate",
      "--force",
      "--length", "48",
    ])

    #expect(command.service == "github.com")
    #expect(command.account == "bot@example.com")
    #expect(command.stdin == true)
    #expect(command.generate == true)
    #expect(command.force == true)
    #expect(command.length == 48)
  }

  @Test("parse maps short options and flags")
  func parseMapsShortOptionsAndFlags() throws {
    let command = try UpdateCommand.parse(arguments: [
      "-s", "api.openai.com",
      "-a", "bot@example.com",
      "-g",
      "-n", "64",
    ])

    #expect(command.service == "api.openai.com")
    #expect(command.account == "bot@example.com")
    #expect(command.stdin == false)
    #expect(command.generate == true)
    #expect(command.force == false)
    #expect(command.length == 64)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try UpdateCommand.parse(arguments: [
      "--service=example.com",
      "--account=bot@example.com",
      "--length=72",
      "--force",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.length == 72)
    #expect(command.force == true)
  }

  @Test("parse rejects unknown arguments")
  func parseRejectsUnknownArguments() {
    #expect(throws: UpdateCommandError.unknownArgument("--bad-flag")) {
      _ = try UpdateCommand.parse(arguments: [
        "--service", "example.com",
        "--account", "bot@example.com",
        "--bad-flag",
      ])
    }
  }

  @Test("parse rejects invalid length values")
  func parseRejectsInvalidLengthValues() {
    #expect(throws: UpdateCommandError.invalidOptionValue(option: "--length", value: "zero")) {
      _ = try UpdateCommand.parse(arguments: ["--length", "zero"])
    }

    #expect(throws: UpdateCommandError.invalidOptionValue(option: "--length", value: "0")) {
      _ = try UpdateCommand.parse(arguments: ["--length", "0"])
    }
  }
}
