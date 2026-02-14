import Foundation

/// Abstraction boundary for password storage.
///
/// Today `applpass` uses `Security.framework` via `KeychainManager`. If Apple
/// introduces a public API for Passwords.app Shared Groups in the future, add a
/// new `PasswordStore` implementation and update `PasswordStoreFactory` to
/// select it without rewriting command logic.
protocol PasswordStore: Sendable {
  func getPassword(for query: KeychainQuery) throws -> KeychainItem

  func listPasswords(
    matching query: KeychainQuery,
    includePasswordData: Bool
  ) throws -> [KeychainItem]

  func addPassword(
    service: String,
    account: String,
    password: String,
    label: String,
    sync: Bool
  ) throws

  func updatePassword(
    for query: KeychainQuery,
    newPassword: String
  ) throws

  func deletePassword(for query: KeychainQuery) throws
}

/// `PasswordStore` backed by `KeychainManager` and Security.framework.
struct SecurityKeychainPasswordStore: PasswordStore {
  private let manager: KeychainManager

  init(manager: KeychainManager = KeychainManager()) {
    self.manager = manager
  }

  func getPassword(for query: KeychainQuery) throws -> KeychainItem {
    try manager.getPassword(for: query)
  }

  func listPasswords(
    matching query: KeychainQuery,
    includePasswordData: Bool
  ) throws -> [KeychainItem] {
    try manager.listPasswords(
      matching: query,
      includePasswordData: includePasswordData
    )
  }

  func addPassword(
    service: String,
    account: String,
    password: String,
    label: String,
    sync: Bool
  ) throws {
    try manager.addPassword(
      service: service,
      account: account,
      password: password,
      label: label,
      sync: sync
    )
  }

  func updatePassword(
    for query: KeychainQuery,
    newPassword: String
  ) throws {
    try manager.updatePassword(for: query, newPassword: newPassword)
  }

  func deletePassword(for query: KeychainQuery) throws {
    try manager.deletePassword(for: query)
  }
}

enum PasswordStoreFactory {
  static func make() -> any PasswordStore {
    SecurityKeychainPasswordStore()
  }
}

