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

  @Test("listPasswords builds query with service/account filters and numeric match limit")
  func listPasswordsBuildsFilteredQueryWithNumericMatchLimit() throws {
    let manager = KeychainManager { query, _ in
      let dictionary = query as NSDictionary

      #expect(dictionary[kSecClass as String] as? String == kSecClassGenericPassword as String)
      #expect(dictionary[kSecAttrService as String] as? String == "cli-tool")
      #expect(dictionary[kSecAttrAccount as String] as? String == "bot@example.com")
      #expect((dictionary[kSecMatchLimit as String] as? NSNumber)?.intValue == 100)
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
      limit: 100
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

  @Test("listPasswords can return metadata without requesting password data")
  func listPasswordsSupportsMetadataOnlyQueries() throws {
    let manager = KeychainManager { query, result in
      let dictionary = query as NSDictionary
      #expect(
        (dictionary[kSecReturnAttributes as String] as? NSNumber)?.boolValue == true
      )
      #expect(dictionary[kSecReturnData as String] == nil)

      let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrService as String: "metadata-only.example.com",
        kSecAttrAccount as String: "bot@example.com",
        kSecAttrSynchronizable as String: false,
      ]
      result?.pointee = item as CFDictionary
      return errSecSuccess
    }
    let query = KeychainQuery(
      service: "metadata-only.example.com",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 10
    )

    let items = try manager.listPasswords(matching: query, includePasswordData: false)
    #expect(items.count == 1)
    #expect(items[0].service == "metadata-only.example.com")
    #expect(items[0].account == "bot@example.com")
    #expect(items[0].password.isEmpty)
  }

  @Test("listPasswords metadata-only mode ignores non-UTF8 password bytes")
  func listPasswordsMetadataOnlyIgnoresUndecodablePasswordData() throws {
    let manager = KeychainManager { _, result in
      let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrService as String: "binary-secret.example.com",
        kSecAttrAccount as String: "bot@example.com",
        kSecValueData as String: Data([0xFF, 0xFE]),
        kSecAttrSynchronizable as String: true,
      ]
      result?.pointee = item as CFDictionary
      return errSecSuccess
    }
    let query = KeychainQuery(
      service: nil,
      account: nil,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 100
    )

    let items = try manager.listPasswords(matching: query, includePasswordData: false)
    #expect(items.count == 1)
    #expect(items[0].service == "binary-secret.example.com")
    #expect(items[0].account == "bot@example.com")
    #expect(items[0].password.isEmpty)
  }

  @Test("listPasswords metadata-only mode skips malformed entries")
  func listPasswordsMetadataOnlySkipsMalformedEntries() throws {
    let manager = KeychainManager { _, result in
      let valid: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrService as String: "valid.example.com",
        kSecAttrAccount as String: "bot@example.com",
        kSecAttrSynchronizable as String: false,
      ]
      let malformed: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrService as String: "",
        kSecAttrAccount as String: "",
      ]
      result?.pointee = [valid, malformed] as CFArray
      return errSecSuccess
    }
    let query = KeychainQuery(
      service: nil,
      account: nil,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 100
    )

    let items = try manager.listPasswords(matching: query, includePasswordData: false)
    #expect(items.count == 1)
    #expect(items[0].service == "valid.example.com")
    #expect(items[0].account == "bot@example.com")
  }
}
