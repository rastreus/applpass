import Testing
@testable import ApplPass

@Suite("List Command Parsing Tests")
struct ListCommandParsingTests {
  @Test("parse maps long options and flags")
  func parseMapsLongOptionsAndFlags() throws {
    let command = try ListCommand.parse(arguments: [
      "--service", "example.com",
      "--account", "bot@example.com",
      "--search", "prod",
      "--format", "json",
      "--shared-only",
      "--show-passwords",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.search == "prod")
    #expect(command.format == .json)
    #expect(command.sharedOnly == true)
    #expect(command.personalOnly == false)
    #expect(command.showPasswords == true)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try ListCommand.parse(arguments: [
      "--service=accounts.example.com",
      "--account=bot@example.com",
      "--search=staging",
      "--format=csv",
      "--personal-only",
    ])

    #expect(command.service == "accounts.example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.search == "staging")
    #expect(command.format == .csv)
    #expect(command.sharedOnly == false)
    #expect(command.personalOnly == true)
    #expect(command.showPasswords == false)
  }

  @Test("parse rejects unknown arguments")
  func parseRejectsUnknownArguments() {
    #expect(throws: ListCommandError.unknownArgument("--invalid")) {
      _ = try ListCommand.parse(arguments: [
        "--service", "example.com",
        "--invalid",
      ])
    }
  }

  @Test("parse rejects invalid format value")
  func parseRejectsInvalidFormat() {
    #expect(throws: ListCommandError.invalidOptionValue(option: "--format", value: "yaml")) {
      _ = try ListCommand.parse(arguments: [
        "--format", "yaml",
      ])
    }
  }
}
