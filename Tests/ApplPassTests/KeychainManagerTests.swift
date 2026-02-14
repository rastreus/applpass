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
}
