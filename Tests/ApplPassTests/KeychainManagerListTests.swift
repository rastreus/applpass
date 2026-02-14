import Security
import Testing
@testable import ApplPass

@Suite("Keychain Manager List Tests")
struct KeychainManagerListTests {
  @Test("listPasswords returns empty array for no matching items")
  func listPasswordsReturnsEmptyForNoMatches() throws {
    let manager = KeychainManager { _, _ in
      errSecItemNotFound
    }
    let query = KeychainQuery(
      service: "missing-service",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 100
    )

    let items = try manager.listPasswords(matching: query)
    #expect(items.isEmpty)
  }
}
