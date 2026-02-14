import Foundation

/// Errors that can occur while interacting with keychain items.
enum KeychainError: Error, Sendable, Equatable, LocalizedError {
  /// No matching keychain item was found for the requested query.
  case itemNotFound
  /// A keychain item already exists for the same unique attributes.
  case duplicateItem
  /// Returned keychain password bytes could not be decoded as text.
  case unexpectedPasswordData
  /// User denied authorization to access keychain data.
  case authorizationDenied
  /// A keychain API returned an unhandled status code.
  case operationFailed(Int32)
  /// Caller supplied an invalid argument.
  case invalidParameter(String)

  var errorDescription: String? {
    switch self {
    case .itemNotFound:
      return "Password not found in keychain."
    case .duplicateItem:
      return "A password with these credentials already exists."
    case .unexpectedPasswordData:
      return "Unable to decode password data."
    case .authorizationDenied:
      return "Access denied. Please allow access when prompted."
    case .operationFailed(let status):
      return "Keychain operation failed with status \(status)."
    case .invalidParameter(let message):
      return "Invalid parameter: \(message)"
    }
  }
}
