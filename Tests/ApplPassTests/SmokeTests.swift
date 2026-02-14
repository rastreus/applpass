import Testing
@testable import ApplPass

@Suite("Smoke Tests")
struct SmokeTests {
  @Test("Version constant is set")
  func versionConstantIsSet() {
    #expect(!ApplPass.version.isEmpty)
  }

  @Test("Command configuration exposes version")
  func commandConfigurationHasVersion() {
    #expect(ApplPass.configuration.version == ApplPass.version)
  }

  @Test("Missing command error lists available subcommands")
  func missingCommandErrorListsAvailableSubcommands() {
    let commands = ApplPass.supportedSubcommands.joined(separator: ", ")

    #expect(
      ApplPassCommandError.missingSubcommand.description
        == "Missing command. Available commands: \(commands)."
    )
  }

  @Test("Unknown command error lists available subcommands")
  func unknownCommandErrorListsAvailableSubcommands() {
    let commands = ApplPass.supportedSubcommands.joined(separator: ", ")

    #expect(
      ApplPassCommandError.unknownSubcommand("bad").description
        == "Unknown command 'bad'. Available commands: \(commands)."
    )
  }
}
