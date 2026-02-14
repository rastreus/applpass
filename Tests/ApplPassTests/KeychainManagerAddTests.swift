import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Keychain Manager Add Unit Tests")
struct KeychainManagerAddUnitTests {
  @Test(
    "addPassword builds add query with expected attributes",
    arguments: [true, false]
  )
  func addPasswordBuildsExpectedAttributes(sync: Bool) throws {
    let manager = KeychainManager(add: { query, _ in
      let dictionary = query as NSDictionary

      #expect(
        dictionary[kSecClass as String] as? String == kSecClassGenericPassword as String
      )
      #expect(dictionary[kSecAttrService as String] as? String == "cli-tool")
      #expect(dictionary[kSecAttrAccount as String] as? String == "bot@example.com")
      #expect(dictionary[kSecAttrLabel as String] as? String == "CLI Bot")
      #expect(dictionary[kSecValueData as String] as? Data == Data("secret-value".utf8))
      #expect((dictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue == sync)

      return errSecSuccess
    })

    try manager.addPassword(
      service: "cli-tool",
      account: "bot@example.com",
      password: "secret-value",
      label: "CLI Bot",
      sync: sync
    )
  }

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
