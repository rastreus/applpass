import Foundation
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

  @Test("listPasswords builds query with service/account filters and match-limit-all")
  func listPasswordsBuildsFilteredQueryWithMatchLimitAll() throws {
    let manager = KeychainManager { query, _ in
      let dictionary = query as NSDictionary

      #expect(dictionary[kSecClass as String] as? String == kSecClassGenericPassword as String)
      #expect(dictionary[kSecAttrService as String] as? String == "cli-tool")
      #expect(dictionary[kSecAttrAccount as String] as? String == "bot@example.com")
      #expect(dictionary[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String)
      #expect(
        (dictionary[kSecReturnAttributes as String] as? NSNumber)?.boolValue == true
      )
      #expect((dictionary[kSecReturnData as String] as? NSNumber)?.boolValue == true)
      #expect((dictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue == false)

      return errSecItemNotFound
    }
    let query = KeychainQuery(
      service: "cli-tool",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 1
    )

    let items = try manager.listPasswords(matching: query)
    #expect(items.isEmpty)
  }
}
