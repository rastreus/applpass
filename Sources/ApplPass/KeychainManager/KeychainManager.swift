import Foundation
import Security

/// Builds Security-framework query dictionaries for keychain operations.
struct KeychainManager: Sendable {
  /// Converts a high-level query model into a keychain query dictionary.
  ///
  /// - Parameter query: User-facing query filters.
  /// - Returns: A `CFDictionary` that can be passed to Security APIs.
  /// - Throws: `KeychainError.invalidParameter` when string filters are empty.
  static func buildQuery(for query: KeychainQuery) throws -> CFDictionary {
    let service = try normalizedValue(query.service, field: "service")
    let account = try normalizedValue(query.account, field: "account")

    var dictionary: [String: Any] = [kSecClass as String: securityClass(for: query.itemClass)]

    if let service {
      dictionary[serviceAttribute(for: query.itemClass) as String] = service
    }

    if let account {
      dictionary[kSecAttrAccount as String] = account
    }

    return dictionary as CFDictionary
  }

  private static func securityClass(for itemClass: ItemClass) -> CFString {
    switch itemClass {
    case .internetPassword:
      return kSecClassInternetPassword
    case .genericPassword:
      return kSecClassGenericPassword
    }
  }

  private static func serviceAttribute(for itemClass: ItemClass) -> CFString {
    switch itemClass {
    case .internetPassword:
      return kSecAttrServer
    case .genericPassword:
      return kSecAttrService
    }
  }

  private static func normalizedValue(
    _ value: String?,
    field: String
  ) throws -> String? {
    guard let value else {
      return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw KeychainError.invalidParameter("\(field) cannot be empty")
    }

    return trimmed
  }
}
