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

  @Test("listPasswords returns all decoded items when keychain returns multiple matches")
  func listPasswordsDecodesMultipleMatches() throws {
    let manager = KeychainManager { _, result in
      let firstItem: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrService as String: "cli-tool",
        kSecAttrAccount as String: "bot-one@example.com",
        kSecValueData as String: Data("secret-one".utf8),
        kSecAttrSynchronizable as String: false,
      ]
      let secondItem: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrService as String: "cli-tool",
        kSecAttrAccount as String: "bot-two@example.com",
        kSecValueData as String: Data("secret-two".utf8),
        kSecAttrSynchronizable as String: false,
      ]
      result?.pointee = [firstItem, secondItem] as CFArray
      return errSecSuccess
    }
    let query = KeychainQuery(
      service: "cli-tool",
      account: nil,
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 100
    )

    let items = try manager.listPasswords(matching: query)
    #expect(items.count == 2)
    #expect(items.map(\.account) == ["bot-one@example.com", "bot-two@example.com"])
    #expect(items.map(\.password) == ["secret-one", "secret-two"])
  }

  @Test("listPasswords includes shared-password groups when includeShared is true")
  func listPasswordsIncludesSharedGroupsWhenRequested() throws {
    let manager = KeychainManager { query, _ in
      let dictionary = query as NSDictionary
      #expect(
        dictionary[kSecAttrSynchronizable as String] as? String
          == kSecAttrSynchronizableAny as String
      )

      return errSecItemNotFound
    }
    let query = KeychainQuery(
      service: "accounts.example.com",
      account: "bot@example.com",
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 100
    )

    let items = try manager.listPasswords(matching: query)
    #expect(items.isEmpty)
  }
}
