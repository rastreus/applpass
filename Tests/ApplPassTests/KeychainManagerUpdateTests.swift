import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Keychain Manager Update Unit Tests")
struct KeychainManagerUpdateUnitTests {
  @Test("updatePassword builds SecItemUpdate query and updates only password data")
  func updatePasswordBuildsExpectedQueryAndUpdateAttributes() throws {
    let manager = KeychainManager(update: { query, attributesToUpdate in
      let queryDictionary = query as NSDictionary
      let updateDictionary = attributesToUpdate as NSDictionary

      #expect(queryDictionary[kSecClass as String] as? String == kSecClassGenericPassword as String)
      #expect(queryDictionary[kSecAttrService as String] as? String == "cli-tool")
      #expect(queryDictionary[kSecAttrAccount as String] as? String == "bot@example.com")
      #expect((queryDictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue == false)
      #expect(queryDictionary[kSecMatchLimit as String] == nil)
      #expect(queryDictionary[kSecReturnAttributes as String] == nil)
      #expect(queryDictionary[kSecReturnData as String] == nil)

      #expect(updateDictionary.count == 1)
      #expect(updateDictionary[kSecValueData as String] as? Data == Data("new-secret".utf8))
      #expect(updateDictionary[kSecAttrService as String] == nil)
      #expect(updateDictionary[kSecAttrAccount as String] == nil)
      #expect(updateDictionary[kSecAttrLabel as String] == nil)

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

    try manager.updatePassword(for: query, newPassword: "new-secret")
  }

  @Test("updatePassword maps missing item to KeychainError.itemNotFound")
  func updatePasswordMapsItemNotFound() {
    let manager = KeychainManager(update: { _, _ in
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

    #expect(throws: KeychainError.itemNotFound) {
      try manager.updatePassword(for: query, newPassword: "new-secret")
    }
  }

  @Test("updatePassword rejects empty replacement password")
  func updatePasswordRejectsEmptyReplacementPassword() {
    let manager = KeychainManager(update: { _, _ in
      Issue.record("updatePassword should not call SecItemUpdate for invalid input")
      return errSecSuccess
    })
    let query = KeychainQuery(
      service: "cli-tool",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 1
    )

    #expect(throws: KeychainError.invalidParameter("newPassword cannot be empty")) {
      try manager.updatePassword(for: query, newPassword: "")
    }
  }
}

@Suite(.serialized)
struct KeychainManagerUpdateIntegrationTests {
  @Test("updatePassword modifies only password while preserving item metadata")
  func updatePasswordUpdatesStoredPasswordAndPreservesMetadata() throws {
    let keychain = UpdateTestKeychain()
    let service = "applpass.update.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let originalPassword = "original-\(UUID().uuidString)"
    let updatedPassword = "updated-\(UUID().uuidString)"
    let label = "ApplPass Update Integration"

    defer {
      let cleanupStatus = keychain.deleteGenericPassword(service: service, account: account)
      #expect([errSecSuccess, errSecItemNotFound].contains(cleanupStatus))
    }

    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add,
      update: keychain.update
    )

    try manager.addPassword(
      service: service,
      account: account,
      password: originalPassword,
      label: label,
      sync: false
    )

    let query = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 1
    )

    try manager.updatePassword(for: query, newPassword: updatedPassword)
    let item = try manager.getPassword(for: query)

    #expect(item.service == service)
    #expect(item.account == account)
    #expect(item.label == label)
    #expect(item.itemClass == .genericPassword)
    #expect(item.password == updatedPassword)
    #expect(item.password != originalPassword)
  }
}

private final class UpdateTestKeychain: @unchecked Sendable {
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

  func update(
    _ query: CFDictionary,
    _ attributesToUpdate: CFDictionary
  ) -> OSStatus {
    let queryDictionary = query as NSDictionary
    let itemClass = queryDictionary[kSecClass as String] as? String
    let service = queryDictionary[kSecAttrService as String] as? String
    let account = queryDictionary[kSecAttrAccount as String] as? String

    guard
      let itemIndex = items.firstIndex(where: {
        $0[kSecClass as String] as? String == itemClass
          && $0[kSecAttrService as String] as? String == service
          && $0[kSecAttrAccount as String] as? String == account
      })
    else {
      return errSecItemNotFound
    }

    let updateDictionary = attributesToUpdate as NSDictionary
    guard let passwordData = updateDictionary[kSecValueData as String] as? Data else {
      return errSecParam
    }

    items[itemIndex][kSecValueData as String] = passwordData
    return errSecSuccess
  }

  func deleteGenericPassword(service: String, account: String) -> OSStatus {
    let originalCount = items.count
    items.removeAll {
      $0[kSecClass as String] as? String == kSecClassGenericPassword as String
        && $0[kSecAttrService as String] as? String == service
        && $0[kSecAttrAccount as String] as? String == account
    }

    if items.count == originalCount {
      return errSecItemNotFound
    }

    return errSecSuccess
  }
}
