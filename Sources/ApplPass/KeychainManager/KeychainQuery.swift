/// Query parameters for searching keychain items.
struct KeychainQuery: Sendable, Equatable, Codable {
  /// Optional service filter, for example `github.com`.
  var service: String?
  /// Optional account filter.
  var account: String?
  /// Optional domain filter used by internet password queries.
  var domain: String?
  /// Whether shared password items should be included.
  var includeShared: Bool = true
  /// Keychain class to query.
  var itemClass: ItemClass = .internetPassword
  /// Maximum number of items to return.
  var limit: Int = 100
}
