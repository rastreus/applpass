import Foundation
import Security

/// Builds Security-framework query dictionaries for keychain operations.
struct KeychainManager: Sendable {
  typealias CopyMatchingFunction =
    @Sendable (
      CFDictionary,
      UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus

  private let copyMatching: CopyMatchingFunction

  init(copyMatching: @escaping CopyMatchingFunction = SecItemCopyMatching) {
    self.copyMatching = copyMatching
  }

  /// Retrieves one password item from keychain and decodes its metadata.
  ///
  /// - Parameter query: Filters used to locate an item.
  /// - Returns: A populated `KeychainItem` value.
  /// - Throws: `KeychainError` when lookup fails or returned data is invalid.
  ///
  /// Example:
  /// ```swift
  /// let manager = KeychainManager()
  /// let query = KeychainQuery(
  ///   service: "github.com",
  ///   account: "bot@example.com",
  ///   domain: nil,
  ///   includeShared: true,
  ///   itemClass: .internetPassword,
  ///   limit: 1
  /// )
  /// let item = try manager.getPassword(for: query)
  /// ```
  func getPassword(for query: KeychainQuery) throws -> KeychainItem {
    var result: CFTypeRef?
    let dictionary = try retrievalQuery(for: query)
    let status = copyMatching(dictionary as CFDictionary, &result)

    guard status == errSecSuccess else {
      throw Self.mappedError(for: status)
    }

    guard let attributes = result as? [String: Any] else {
      throw KeychainError.unexpectedPasswordData
    }

    return try Self.decodeItem(from: attributes, fallbackQuery: query)
  }

  /// Lists all keychain password items matching the provided filters.
  ///
  /// - Parameter query: Filters used to match keychain items.
  /// - Returns: Matching items. Returns an empty array when no items are found.
  /// - Throws: `KeychainError` when lookup fails for reasons other than not found.
  func listPasswords(matching query: KeychainQuery) throws -> [KeychainItem] {
    var result: CFTypeRef?
    let dictionary = try listingQuery(for: query)
    let status = copyMatching(dictionary as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      return []
    case errSecItemNotFound:
      return []
    default:
      throw Self.mappedError(for: status)
    }
  }

  /// Converts a high-level query model into a keychain query dictionary.
  ///
  /// - Parameter query: User-facing query filters.
  /// - Returns: A `CFDictionary` that can be passed to Security APIs.
  /// - Throws: `KeychainError.invalidParameter` when string filters are empty.
  ///
  /// Example:
  /// ```swift
  /// let query = KeychainQuery(
  ///   service: "github.com",
  ///   account: "bot@example.com",
  ///   domain: nil,
  ///   includeShared: true,
  ///   itemClass: .internetPassword,
  ///   limit: 1
  /// )
  /// let dictionary = try KeychainManager.buildQuery(for: query)
  /// ```
  static func buildQuery(for query: KeychainQuery) throws -> CFDictionary {
    try validate(query)

    let service = try normalizedValue(query.service, field: "service")
    let account = try normalizedValue(query.account, field: "account")
    let domain = try normalizedValue(query.domain, field: "domain")

    var dictionary: [String: Any] = [kSecClass as String: securityClass(for: query.itemClass)]

    if let service {
      dictionary[serviceAttribute(for: query.itemClass) as String] = service
    }

    if let account {
      dictionary[kSecAttrAccount as String] = account
    }

    if let domain, query.itemClass == .internetPassword {
      dictionary[kSecAttrSecurityDomain as String] = domain
    }

    dictionary[kSecAttrSynchronizable as String] =
      query.includeShared ? kSecAttrSynchronizableAny : kCFBooleanFalse
    dictionary[kSecMatchLimit as String] = matchLimitValue(for: query.limit)

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

  private static func validate(_ query: KeychainQuery) throws {
    guard query.limit > 0 else {
      throw KeychainError.invalidParameter("limit must be greater than 0")
    }

    let domain = query.domain?.trimmingCharacters(in: .whitespacesAndNewlines)
    if query.itemClass == .genericPassword, let domain, !domain.isEmpty {
      throw KeychainError.invalidParameter(
        "domain is only supported for internet password items"
      )
    }
  }

  private static func matchLimitValue(for limit: Int) -> Any {
    if limit == 1 {
      return kSecMatchLimitOne
    }

    return limit
  }

  private func retrievalQuery(for query: KeychainQuery) throws -> [String: Any] {
    guard var dictionary = try Self.buildQuery(for: query) as NSDictionary as? [String: Any] else {
      throw KeychainError.operationFailed(errSecParam)
    }

    dictionary[kSecReturnAttributes as String] = kCFBooleanTrue
    dictionary[kSecReturnData as String] = kCFBooleanTrue
    dictionary[kSecMatchLimit as String] = kSecMatchLimitOne

    return dictionary
  }

  private func listingQuery(for query: KeychainQuery) throws -> [String: Any] {
    guard var dictionary = try Self.buildQuery(for: query) as NSDictionary as? [String: Any] else {
      throw KeychainError.operationFailed(errSecParam)
    }

    dictionary[kSecReturnAttributes as String] = kCFBooleanTrue
    dictionary[kSecReturnData as String] = kCFBooleanTrue
    dictionary[kSecMatchLimit as String] = kSecMatchLimitAll

    return dictionary
  }

  private static func mappedError(for status: OSStatus) -> KeychainError {
    switch status {
    case errSecItemNotFound:
      return .itemNotFound
    case errSecAuthFailed, errSecUserCanceled:
      return .authorizationDenied
    default:
      return .operationFailed(status)
    }
  }

  private static func decodeItem(
    from attributes: [String: Any],
    fallbackQuery: KeychainQuery
  ) throws -> KeychainItem {
    guard
      let passwordData = attributes[kSecValueData as String] as? Data,
      let password = String(data: passwordData, encoding: .utf8)
    else {
      throw KeychainError.unexpectedPasswordData
    }

    let serviceKey = serviceAttribute(for: fallbackQuery.itemClass) as String
    let service = try decodedRequiredString(
      primary: attributes[serviceKey] as? String,
      fallback: fallbackQuery.service,
      field: "service"
    )
    let account = try decodedRequiredString(
      primary: attributes[kSecAttrAccount as String] as? String,
      fallback: fallbackQuery.account,
      field: "account"
    )
    let itemClass = decodedItemClass(
      rawValue: attributes[kSecClass as String] as? String,
      fallback: fallbackQuery.itemClass
    )

    return KeychainItem(
      service: service,
      account: account,
      password: password,
      label: attributes[kSecAttrLabel as String] as? String,
      creationDate: attributes[kSecAttrCreationDate as String] as? Date,
      modificationDate: attributes[kSecAttrModificationDate as String] as? Date,
      isShared: decodedSharedValue(from: attributes[kSecAttrSynchronizable as String]),
      sharedGroupName: attributes[kSecAttrAccessGroup as String] as? String,
      itemClass: itemClass
    )
  }

  private static func decodedRequiredString(
    primary: String?,
    fallback: String?,
    field: String
  ) throws -> String {
    if let primary, !primary.isEmpty {
      return primary
    }

    if let fallback = try normalizedValue(fallback, field: field) {
      return fallback
    }

    throw KeychainError.unexpectedPasswordData
  }

  private static func decodedItemClass(rawValue: String?, fallback: ItemClass) -> ItemClass {
    let internetPasswordClass = kSecClassInternetPassword as String
    let genericPasswordClass = kSecClassGenericPassword as String

    switch rawValue {
    case internetPasswordClass:
      return .internetPassword
    case genericPasswordClass:
      return .genericPassword
    default:
      return fallback
    }
  }

  private static func decodedSharedValue(from value: Any?) -> Bool {
    if let bool = value as? Bool {
      return bool
    }

    if let number = value as? NSNumber {
      return number.boolValue
    }

    if let string = value as? String {
      if string == kSecAttrSynchronizableAny as String {
        return true
      }

      return NSString(string: string).boolValue
    }

    return false
  }
}
