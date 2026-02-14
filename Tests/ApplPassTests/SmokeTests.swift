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
}
