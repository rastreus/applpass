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
    #expect(
      ApplPassCommandError.missingSubcommand.description
        == "Missing command. Available commands: add, get, list."
    )
  }

  @Test("Unknown command error lists available subcommands")
  func unknownCommandErrorListsAvailableSubcommands() {
    #expect(
      ApplPassCommandError.unknownSubcommand("bad").description
        == "Unknown command 'bad'. Available commands: add, get, list."
    )
  }
}
