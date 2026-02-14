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

  @Test("addPassword rejects empty password input")
  func addPasswordRejectsEmptyPassword() {
    let manager = KeychainManager(add: { _, _ in
      Issue.record("addPassword should not call SecItemAdd for invalid input")
      return errSecSuccess
    })

    #expect(throws: KeychainError.invalidParameter("password cannot be empty")) {
      try manager.addPassword(
        service: "cli-tool",
        account: "bot@example.com",
        password: "",
        label: "CLI Bot",
        sync: false
      )
    }
  }
}

@Suite(.serialized)
struct KeychainManagerAddIntegrationTests {
  @Test("addPassword stores an item that can be retrieved with getPassword")
  func addPasswordStoresAndRetrievesItem() throws {
    let keychain = AddTestKeychain()
    let service = "applpass.add.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let password = "secret-\(UUID().uuidString)"
    let label = "ApplPass Add Integration"

    defer {
      let cleanupStatus = keychain.deleteGenericPassword(service: service, account: account)
      #expect([errSecSuccess, errSecItemNotFound].contains(cleanupStatus))
    }

    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add
    )

    try manager.addPassword(
      service: service,
      account: account,
      password: password,
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
    let item = try manager.getPassword(for: query)

    #expect(item.service == service)
    #expect(item.account == account)
    #expect(item.password == password)
    #expect(item.label == label)
    #expect(item.isShared == false)
    #expect(item.itemClass == .genericPassword)
  }
}

private final class AddTestKeychain: @unchecked Sendable {
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
      kSecAttrLabel as String: dictionary[kSecAttrLabel as String] as? String as Any,
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

  func deleteGenericPassword(service: String, account: String) -> OSStatus {
    let initialCount = items.count
    items.removeAll {
      $0[kSecClass as String] as? String == kSecClassGenericPassword as String
        && $0[kSecAttrService as String] as? String == service
        && $0[kSecAttrAccount as String] as? String == account
    }

    if items.count == initialCount {
      return errSecItemNotFound
    }

    return errSecSuccess
  }
}
