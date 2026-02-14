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
  /// Indicates whether the item belongs to a shared password group.
  let isShared: Bool
  /// Optional name of the shared password group.
  let sharedGroupName: String?
  /// Keychain class used for the stored credential.
  let itemClass: ItemClass
}
