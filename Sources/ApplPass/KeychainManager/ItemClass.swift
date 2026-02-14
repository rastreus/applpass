/// Keychain item type used for querying and decoding keychain records.
///
/// `internetPassword` maps to website/API credentials, while
/// `genericPassword` maps to app-specific credentials.
enum ItemClass: String, Sendable, Equatable, Codable {
  case internetPassword
  case genericPassword
}
