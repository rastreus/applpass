import Security
import Testing
@testable import ApplPass

@Suite("Keychain Manager Add Unit Tests")
struct KeychainManagerAddUnitTests {
  @Test("addPassword maps duplicate-item status to KeychainError.duplicateItem")
  func addPasswordMapsDuplicateItemError() {
    let manager = KeychainManager(add: { _, _ in
      errSecDuplicateItem
    })

    #expect(throws: KeychainError.duplicateItem) {
      try manager.addPassword(
        service: "cli-tool",
        account: "bot@example.com",
        password: "secret-value",
        label: "CLI Bot",
        sync: false
      )
    }
  }
}
