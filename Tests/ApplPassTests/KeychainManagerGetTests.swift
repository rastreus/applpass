import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Keychain Manager Get Unit Tests")
struct KeychainManagerGetUnitTests {
  @Test("getPassword decodes password and metadata from keychain response")
  func getPasswordDecodesItemFromResultDictionary() throws {
    let creationDate = Date(timeIntervalSince1970: 1_739_200_100)
    let modificationDate = Date(timeIntervalSince1970: 1_739_200_200)

    let manager = KeychainManager { query, result in
      let dictionary = query as NSDictionary

      guard dictionary[kSecClass as String] as? String == kSecClassGenericPassword as String else {
        return errSecParam
      }

      guard dictionary[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String else {
        return errSecParam
      }

      guard
        (dictionary[kSecReturnData as String] as? NSNumber)?.boolValue == true,
        (dictionary[kSecReturnAttributes as String] as? NSNumber)?.boolValue == true
      else {
        return errSecParam
      }

      let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrService as String: "cli-tool",
        kSecAttrAccount as String: "bot@example.com",
        kSecValueData as String: Data("secret-value".utf8),
        kSecAttrLabel as String: "CLI Bot",
        kSecAttrCreationDate as String: creationDate,
        kSecAttrModificationDate as String: modificationDate,
        kSecAttrSynchronizable as String: false,
        kSecAttrAccessGroup as String: "Team Credentials",
      ]
      result?.pointee = item as CFDictionary
      return errSecSuccess
    }

    let query = KeychainQuery(
      service: "cli-tool",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 99
    )

    let item = try manager.getPassword(for: query)
    #expect(item.service == "cli-tool")
    #expect(item.account == "bot@example.com")
    #expect(item.password == "secret-value")
    #expect(item.label == "CLI Bot")
    #expect(item.creationDate == creationDate)
    #expect(item.modificationDate == modificationDate)
    #expect(item.isShared == false)
    #expect(item.sharedGroupName == "Team Credentials")
    #expect(item.itemClass == .genericPassword)
  }

  @Test("getPassword maps item-not-found status to KeychainError.itemNotFound")
  func getPasswordMapsItemNotFoundError() {
    let manager = KeychainManager { _, _ in
      errSecItemNotFound
    }

    let query = KeychainQuery(
      service: "missing-service",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 1
    )

    #expect(throws: KeychainError.itemNotFound) {
      _ = try manager.getPassword(for: query)
    }
  }

  @Test(
    "getPassword maps authorization statuses to KeychainError.authorizationDenied",
    arguments: [errSecAuthFailed, errSecUserCanceled]
  )
  func getPasswordMapsAuthorizationDenied(status: OSStatus) {
    let manager = KeychainManager { _, _ in
      status
    }

    let query = KeychainQuery(
      service: "protected-service",
      account: "bot@example.com",
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 1
    )

    #expect(throws: KeychainError.authorizationDenied) {
      _ = try manager.getPassword(for: query)
    }
  }

  @Test("getPassword throws unexpectedPasswordData for undecodable password bytes")
  func getPasswordThrowsForUndecodablePasswordData() {
    let manager = KeychainManager { _, result in
      let item: [String: Any] = [
        kSecAttrServer as String: "example.com",
        kSecAttrAccount as String: "bot@example.com",
        kSecValueData as String: Data([0xFF, 0xFE]),
      ]
      result?.pointee = item as CFDictionary
      return errSecSuccess
    }

    let query = KeychainQuery(
      service: "example.com",
      account: "bot@example.com",
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 1
    )

    #expect(throws: KeychainError.unexpectedPasswordData) {
      _ = try manager.getPassword(for: query)
    }
  }
}

@Suite(.serialized)
struct KeychainManagerGetIntegrationTests {
  @Test("getPassword retrieves an item previously added to the test keychain")
  func getPasswordRetrievesAddedItem() throws {
    let keychain = TestKeychain()
    let service = "applpass.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let password = "secret-\(UUID().uuidString)"
    let label = "ApplPass Integration"

    keychain.addGenericPassword(
      service: service,
      account: account,
      password: password,
      label: label
    )

    let manager = KeychainManager(copyMatching: keychain.copyMatching)
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

private final class TestKeychain: @unchecked Sendable {
  private var items: [[String: Any]] = []

  func addGenericPassword(
    service: String,
    account: String,
    password: String,
    label: String
  ) {
    items.append([
      kSecClass as String: kSecClassGenericPassword as String,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrLabel as String: label,
      kSecAttrSynchronizable as String: false,
      kSecValueData as String: Data(password.utf8),
    ])
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
}
