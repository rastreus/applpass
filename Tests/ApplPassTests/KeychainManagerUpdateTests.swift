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
