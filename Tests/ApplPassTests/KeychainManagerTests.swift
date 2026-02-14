import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Keychain Manager Tests")
struct KeychainManagerTests {
  @Test("buildQuery maps internet-password class, server, and account")
  func buildQueryInternetPasswordBaseMapping() throws {
    let query = KeychainQuery(
      service: "github.com",
      account: "bot@example.com",
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 100
    )

    let dictionary = try KeychainManager.buildQuery(for: query) as NSDictionary

    #expect(dictionary[kSecClass as String] as? String == kSecClassInternetPassword as String)
    #expect(dictionary[kSecAttrServer as String] as? String == "github.com")
    #expect(dictionary[kSecAttrAccount as String] as? String == "bot@example.com")
  }

  @Test("buildQuery includes synchronizable-any when shared items are included")
  func buildQueryIncludeSharedSetsSynchronizableAny() throws {
    let query = KeychainQuery(
      service: "github.com",
      account: "bot@example.com",
      domain: nil,
      includeShared: true,
      itemClass: .internetPassword,
      limit: 100
    )

    let dictionary = try KeychainManager.buildQuery(for: query) as NSDictionary
    #expect(
      dictionary[kSecAttrSynchronizable as String] as? String
        == kSecAttrSynchronizableAny as String
    )
  }

  @Test("buildQuery maps explicit single-result limit to kSecMatchLimitOne")
  func buildQuerySingleLimitUsesMatchLimitOne() throws {
    let query = KeychainQuery(
      service: "github.com",
      account: "bot@example.com",
      domain: nil,
      includeShared: false,
      itemClass: .internetPassword,
      limit: 1
    )

    let dictionary = try KeychainManager.buildQuery(for: query) as NSDictionary
    #expect(dictionary[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String)
    let synchronizableValue = dictionary[kSecAttrSynchronizable as String] as? NSNumber
    #expect(synchronizableValue?.boolValue == false)
  }
}
