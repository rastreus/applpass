import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Keychain Manager Delete Unit Tests")
struct KeychainManagerDeleteUnitTests {
  @Test("deletePassword builds SecItemDelete query from keychain filters")
  func deletePasswordBuildsExpectedDeleteQuery() throws {
    let manager = KeychainManager(delete: { query in
      let dictionary = query as NSDictionary

      #expect(dictionary[kSecClass as String] as? String == kSecClassGenericPassword as String)
      #expect(dictionary[kSecAttrService as String] as? String == "cli-tool")
      #expect(dictionary[kSecAttrAccount as String] as? String == "bot@example.com")
      #expect((dictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue == false)
      #expect(dictionary[kSecMatchLimit as String] == nil)
      #expect(dictionary[kSecReturnAttributes as String] == nil)
      #expect(dictionary[kSecReturnData as String] == nil)

      return errSecSuccess
    })
    let query = KeychainQuery(
      service: "cli-tool",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 100
    )

    try manager.deletePassword(for: query)
  }

  @Test("deletePassword is idempotent when keychain item does not exist")
  func deletePasswordIgnoresItemNotFound() throws {
    let manager = KeychainManager(delete: { _ in
      errSecItemNotFound
    })
    let query = KeychainQuery(
      service: "missing-service",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 1
    )

    try manager.deletePassword(for: query)
  }

  @Test("deletePassword maps authorization failures")
  func deletePasswordMapsAuthorizationError() {
    let manager = KeychainManager(delete: { _ in
      errSecAuthFailed
    })
    let query = KeychainQuery(
      service: "protected-service",
      account: "bot@example.com",
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 1
    )

    #expect(throws: KeychainError.authorizationDenied) {
      try manager.deletePassword(for: query)
    }
  }
}
