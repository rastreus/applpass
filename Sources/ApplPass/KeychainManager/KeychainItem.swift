import Foundation

/// Represents a keychain password item and associated metadata.
struct KeychainItem: Sendable, Equatable, Codable {
  /// Service or server name, for example `github.com`.
  let service: String
  /// Account or username associated with the credential.
  let account: String
  /// Decrypted password value for the keychain item.
  let password: String
  /// Optional user-facing label stored in keychain metadata.
  let label: String?
  /// Date when the keychain item was created.
  let creationDate: Date?
  /// Date when the keychain item was last modified.
  let modificationDate: Date?
  /// Indicates whether the item is marked as synchronizable (iCloud Keychain).
  let isShared: Bool
  /// Optional access group identifier returned by Security.framework.
  let sharedGroupName: String?
  /// Keychain class used for the stored credential.
  let itemClass: ItemClass
}
