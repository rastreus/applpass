import Foundation
import Security

/// Builds Security-framework query dictionaries for keychain operations.
struct KeychainManager: Sendable {
  typealias CopyMatchingFunction =
    @Sendable (
      CFDictionary,
      UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
  typealias AddFunction =
    @Sendable (
      CFDictionary,
      UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
  typealias UpdateFunction =
    @Sendable (
      CFDictionary,
      CFDictionary
    ) -> OSStatus
  typealias DeleteFunction =
    @Sendable (
      CFDictionary
    ) -> OSStatus

  private let copyMatching: CopyMatchingFunction
  private let add: AddFunction
  private let update: UpdateFunction
  private let delete: DeleteFunction

  init(
    copyMatching: @escaping CopyMatchingFunction = SecItemCopyMatching,
    add: @escaping AddFunction = SecItemAdd,
    update: @escaping UpdateFunction = SecItemUpdate,
    delete: @escaping DeleteFunction = SecItemDelete
  ) {
    self.copyMatching = copyMatching
    self.add = add
    self.update = update
    self.delete = delete
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
    let status = self.copyMatchingWithFallback(
      dictionary: dictionary,
      result: &result
    )

    guard status == errSecSuccess else {
      throw Self.mappedError(for: status)
    }

    guard let attributes = result as? [String: Any] else {
      throw KeychainError.unexpectedPasswordData
    }

    return try Self.decodeItem(
      from: attributes,
      fallbackQuery: query,
      allowMissingPasswordData: false
    )
  }

  /// Lists all keychain password items matching the provided filters.
  ///
  /// - Parameter query: Filters used to match keychain items.
  /// - Returns: Matching items. Returns an empty array when no items are found.
  /// - Throws: `KeychainError` when lookup fails for reasons other than not found.
  func listPasswords(
    matching query: KeychainQuery,
    includePasswordData: Bool = true
  ) throws -> [KeychainItem] {
    var result: CFTypeRef?
    let dictionary = try listingQuery(for: query, includePasswordData: includePasswordData)
    let status = self.copyMatchingWithFallback(
      dictionary: dictionary,
      result: &result
    )

    switch status {
    case errSecSuccess:
      return try Self.decodeItems(
        from: result,
        fallbackQuery: query,
        allowMissingPasswordData: !includePasswordData
      )
    case errSecItemNotFound:
      return []
    default:
      throw Self.mappedError(for: status)
    }
  }

  /// Adds a new generic-password item to keychain.
  ///
  /// - Parameters:
  ///   - service: Service identifier for the credential.
  ///   - account: Account identifier for the credential.
  ///   - password: Secret value to store.
  ///   - label: User-facing label for the keychain item.
  ///   - sync: Whether the item should synchronize through iCloud keychain.
  /// - Throws: `KeychainError` when insertion fails.
  func addPassword(
    service: String,
    account: String,
    password: String,
    label: String,
    sync: Bool
  ) throws {
    guard
      let normalizedService = try Self.normalizedValue(service, field: "service"),
      let normalizedAccount = try Self.normalizedValue(account, field: "account"),
      let normalizedLabel = try Self.normalizedValue(label, field: "label")
    else {
      throw KeychainError.operationFailed(errSecParam)
    }

    guard !password.isEmpty else {
      throw KeychainError.invalidParameter("password cannot be empty")
    }

    let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: normalizedService,
      kSecAttrAccount as String: normalizedAccount,
      kSecValueData as String: Data(password.utf8),
      kSecAttrLabel as String: normalizedLabel,
      kSecAttrSynchronizable as String: sync,
    ]

    let status = add(attributes as CFDictionary, nil)
    if status == errSecSuccess {
      return
    }

    if status == errSecDuplicateItem {
      throw KeychainError.duplicateItem
    }

    throw Self.mappedError(for: status)
  }

  /// Updates only the password bytes for existing keychain items matching the query.
  ///
  /// - Parameters:
  ///   - query: Filters used to locate existing keychain items.
  ///   - newPassword: Replacement password value.
  /// - Throws: `KeychainError` when no item matches, input is invalid, or update fails.
  func updatePassword(for query: KeychainQuery, newPassword: String) throws {
    guard !newPassword.isEmpty else {
      throw KeychainError.invalidParameter("newPassword cannot be empty")
    }

    let searchQuery = try updateQuery(for: query)
    let attributesToUpdate: [String: Any] = [
      kSecValueData as String: Data(newPassword.utf8)
    ]
    let status = update(
      searchQuery as CFDictionary,
      attributesToUpdate as CFDictionary
    )

    guard status == errSecSuccess else {
      throw Self.mappedError(for: status)
    }
  }

  /// Deletes keychain items matching the provided query.
  ///
  /// Deletion is idempotent: when no matching item exists, this method still succeeds.
  ///
  /// - Parameter query: Filters used to select keychain items to delete.
  /// - Throws: `KeychainError` when deletion fails for reasons other than item-not-found.
  func deletePassword(for query: KeychainQuery) throws {
    let searchQuery = try deleteQuery(for: query)
    let status = delete(searchQuery as CFDictionary)

    switch status {
    case errSecSuccess, errSecItemNotFound:
      return
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

  private func copyMatchingWithFallback(
    dictionary: [String: Any],
    result: inout CFTypeRef?
  ) -> OSStatus {
    let status = copyMatching(dictionary as CFDictionary, &result)
    guard status == errSecParam else {
      return status
    }

    guard let fallbackDictionary = Self.withDefaultSearchList(dictionary) else {
      return status
    }

    return copyMatching(fallbackDictionary as CFDictionary, &result)
  }

  private static func withDefaultSearchList(_ dictionary: [String: Any]) -> [String: Any]? {
    if dictionary[kSecMatchSearchList as String] != nil {
      return nil
    }

    var keychain: SecKeychain?
    let status = SecKeychainCopyDefault(&keychain)
    guard status == errSecSuccess, let keychain else {
      return nil
    }

    var fallbackDictionary = dictionary
    fallbackDictionary[kSecMatchSearchList as String] = [keychain]
    return fallbackDictionary
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

  private func listingQuery(
    for query: KeychainQuery,
    includePasswordData: Bool
  ) throws -> [String: Any] {
    guard var dictionary = try Self.buildQuery(for: query) as NSDictionary as? [String: Any] else {
      throw KeychainError.operationFailed(errSecParam)
    }

    dictionary[kSecReturnAttributes as String] = kCFBooleanTrue
    if includePasswordData {
      dictionary[kSecReturnData as String] = kCFBooleanTrue
    }
    // Keep the caller-provided numeric limit from buildQuery.
    // For password items, forcing kSecMatchLimitAll while requesting data can be
    // rejected by Security.framework with errSecParam.

    return dictionary
  }

  private func updateQuery(for query: KeychainQuery) throws -> [String: Any] {
    guard var dictionary = try Self.buildQuery(for: query) as NSDictionary as? [String: Any] else {
      throw KeychainError.operationFailed(errSecParam)
    }

    dictionary.removeValue(forKey: kSecMatchLimit as String)
    return dictionary
  }

  private func deleteQuery(for query: KeychainQuery) throws -> [String: Any] {
    guard var dictionary = try Self.buildQuery(for: query) as NSDictionary as? [String: Any] else {
      throw KeychainError.operationFailed(errSecParam)
    }

    dictionary.removeValue(forKey: kSecMatchLimit as String)
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
    fallbackQuery: KeychainQuery,
    allowMissingPasswordData: Bool
  ) throws -> KeychainItem {
    let password: String
    if allowMissingPasswordData {
      // Metadata-only listings should not fail on opaque/non-UTF8 secret bytes.
      password = ""
    } else if
      let passwordData = attributes[kSecValueData as String] as? Data,
      let decoded = String(data: passwordData, encoding: .utf8)
    {
      password = decoded
    } else {
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

  private static func decodeItems(
    from result: CFTypeRef?,
    fallbackQuery: KeychainQuery,
    allowMissingPasswordData: Bool
  ) throws -> [KeychainItem] {
    if let attributes = result as? [String: Any] {
      if allowMissingPasswordData {
        return (try? [
          decodeItem(
            from: attributes,
            fallbackQuery: fallbackQuery,
            allowMissingPasswordData: true
          )
        ]) ?? []
      }

      return [
        try decodeItem(
          from: attributes,
          fallbackQuery: fallbackQuery,
          allowMissingPasswordData: allowMissingPasswordData
        )
      ]
    }

    if let itemDictionaries = result as? [[String: Any]] {
      if allowMissingPasswordData {
        return itemDictionaries.compactMap { item in
          try? decodeItem(
            from: item,
            fallbackQuery: fallbackQuery,
            allowMissingPasswordData: true
          )
        }
      }

      return try itemDictionaries.map { item in
        try decodeItem(
          from: item,
          fallbackQuery: fallbackQuery,
          allowMissingPasswordData: allowMissingPasswordData
        )
      }
    }

    throw KeychainError.unexpectedPasswordData
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
