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

@Suite(.serialized)
struct KeychainManagerDeleteIntegrationTests {
  @Test("deletePassword removes an existing item and subsequent get returns itemNotFound")
  func deletePasswordRemovesStoredItem() throws {
    let keychain = DeleteTestKeychain()
    let service = "applpass.delete.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let password = "secret-\(UUID().uuidString)"
    let label = "ApplPass Delete Integration"
    let query = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 1
    )
    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add,
      delete: keychain.delete
    )

    try manager.addPassword(
      service: service,
      account: account,
      password: password,
      label: label,
      sync: false
    )

    try manager.deletePassword(for: query)

    #expect(throws: KeychainError.itemNotFound) {
      _ = try manager.getPassword(for: query)
    }
  }
}

private final class DeleteTestKeychain: @unchecked Sendable {
  private var items: [[String: Any]] = []

  func add(
    _ query: CFDictionary,
    _ result: UnsafeMutablePointer<CFTypeRef?>?
  ) -> OSStatus {
    _ = result

    let dictionary = query as NSDictionary
    guard
      let itemClass = dictionary[kSecClass as String] as? String,
      let service = dictionary[kSecAttrService as String] as? String,
      let account = dictionary[kSecAttrAccount as String] as? String,
      let passwordData = dictionary[kSecValueData as String] as? Data
    else {
      return errSecParam
    }

    if items.contains(where: {
      $0[kSecClass as String] as? String == itemClass
        && $0[kSecAttrService as String] as? String == service
        && $0[kSecAttrAccount as String] as? String == account
    }) {
      return errSecDuplicateItem
    }

    items.append([
      kSecClass as String: itemClass,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrLabel as String: dictionary[kSecAttrLabel as String] as Any,
      kSecAttrSynchronizable as String:
        (dictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue ?? false,
      kSecValueData as String: passwordData,
    ])

    return errSecSuccess
  }

  func copyMatching(
    _ query: CFDictionary,
    _ result: UnsafeMutablePointer<CFTypeRef?>?
  ) -> OSStatus {
    let dictionary = query as NSDictionary
    let itemClass = dictionary[kSecClass as String] as? String
    let service = dictionary[kSecAttrService as String] as? String
    let account = dictionary[kSecAttrAccount as String] as? String

    guard
      let match = items.first(where: {
        $0[kSecClass as String] as? String == itemClass
          && $0[kSecAttrService as String] as? String == service
          && $0[kSecAttrAccount as String] as? String == account
      })
    else {
      return errSecItemNotFound
    }

    result?.pointee = match as CFDictionary
    return errSecSuccess
  }

  func delete(_ query: CFDictionary) -> OSStatus {
    let dictionary = query as NSDictionary
    let itemClass = dictionary[kSecClass as String] as? String
    let service = dictionary[kSecAttrService as String] as? String
    let account = dictionary[kSecAttrAccount as String] as? String

    let initialCount = items.count
    items.removeAll {
      $0[kSecClass as String] as? String == itemClass
        && $0[kSecAttrService as String] as? String == service
        && $0[kSecAttrAccount as String] as? String == account
    }

    if items.count == initialCount {
      return errSecItemNotFound
    }

    return errSecSuccess
  }
}
