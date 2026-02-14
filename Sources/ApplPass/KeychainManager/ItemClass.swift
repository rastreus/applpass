/// Keychain item type used for querying and decoding keychain records.
///
/// `internetPassword` maps to website/API credentials, while
/// `genericPassword` maps to app-specific credentials.
enum ItemClass: String, Sendable, Equatable, Codable {
  case internetPassword
  case genericPassword

  /// Default lookup order when the caller wants "whatever matches", but the
  /// underlying store has multiple item classes.
  static let defaultLookupOrder: [ItemClass] = [.internetPassword, .genericPassword]
}
