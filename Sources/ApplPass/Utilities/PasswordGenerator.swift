import Foundation
import Security

/// Errors thrown by password generation.
enum PasswordGeneratorError: Error, Sendable, Equatable, LocalizedError {
  case invalidLength
  case noCharacterSetsEnabled
  case randomGenerationFailed(Int32)

  var errorDescription: String? {
    switch self {
    case .invalidLength:
      return "Password length must be greater than 0."
    case .noCharacterSetsEnabled:
      return "At least one character set must be enabled."
    case .randomGenerationFailed(let status):
      return "Secure random generation failed with status \(status)."
    }
  }
}

/// Generates cryptographically secure random passwords.
struct PasswordGenerator: Sendable {
  private static let uppercase = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  private static let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
  private static let digits = Array("0123456789")
  private static let symbols = Array("!@#$%^&*()-_=+[]{};:,.<>?/\\|~`")

  static func generate(
    length: Int = 32,
    includeSymbols: Bool = true,
    includeUppercase: Bool = true,
    includeLowercase: Bool = true,
    includeDigits: Bool = true
  ) throws -> String {
    guard length > 0 else {
      throw PasswordGeneratorError.invalidLength
    }

    var pool: [Character] = []
    if includeUppercase { pool += uppercase }
    if includeLowercase { pool += lowercase }
    if includeDigits { pool += digits }
    if includeSymbols { pool += symbols }

    guard !pool.isEmpty else {
      throw PasswordGeneratorError.noCharacterSetsEnabled
    }

    var password: [Character] = []
    password.reserveCapacity(length)

    for _ in 0..<length {
      let index = try secureRandomIndex(upperBound: pool.count)
      password.append(pool[index])
    }

    return String(password)
  }

  private static func secureRandomIndex(upperBound: Int) throws -> Int {
    var randomValue = UInt64.zero
    let status = withUnsafeMutableBytes(of: &randomValue) { rawBuffer in
      guard let baseAddress = rawBuffer.baseAddress else {
        return errSecParam
      }

      return SecRandomCopyBytes(kSecRandomDefault, rawBuffer.count, baseAddress)
    }

    guard status == errSecSuccess else {
      throw PasswordGeneratorError.randomGenerationFailed(status)
    }

    return Int(randomValue % UInt64(upperBound))
  }
}
