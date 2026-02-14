import Testing
@testable import ApplPass

@Suite("Smoke Tests")
struct SmokeTests {
  @Test("Version constant is set")
  func versionConstantIsSet() {
    #expect(!ApplPass.version.isEmpty)
  }
}
