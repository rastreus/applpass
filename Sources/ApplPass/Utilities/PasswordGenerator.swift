import Foundation
import Security

/// Errors thrown by password generation.
enum PasswordGeneratorError: Error, Sendable, Equatable, LocalizedError {
  case invalidLength
  case noCharacterSetsEnabled
  case lengthTooShortForEnabledSets
  case randomGenerationFailed(Int32)

  var errorDescription: String? {
    switch self {
    case .invalidLength:
      return "Password length must be greater than 0."
    case .noCharacterSetsEnabled:
      return "At least one character set must be enabled."
    case .lengthTooShortForEnabledSets:
      return "Password length must be at least the number of enabled character sets."
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

    var enabledSets: [[Character]] = []
    var pool: [Character] = []
    if includeUppercase {
      enabledSets.append(uppercase)
      pool += uppercase
    }
    if includeLowercase {
      enabledSets.append(lowercase)
      pool += lowercase
    }
    if includeDigits {
      enabledSets.append(digits)
      pool += digits
    }
    if includeSymbols {
      enabledSets.append(symbols)
      pool += symbols
    }

    guard !enabledSets.isEmpty else {
      throw PasswordGeneratorError.noCharacterSetsEnabled
    }

    guard length >= enabledSets.count else {
      throw PasswordGeneratorError.lengthTooShortForEnabledSets
    }

    var password: [Character] = []
    password.reserveCapacity(length)

    for characters in enabledSets {
      password.append(try randomCharacter(from: characters))
    }

    for _ in enabledSets.count..<length {
      password.append(try randomCharacter(from: pool))
    }

    try secureShuffle(&password)
    return String(password)
  }

  private static func randomCharacter(from characters: [Character]) throws -> Character {
    let index = try secureRandomIndex(upperBound: characters.count)
    return characters[index]
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

  private static func secureShuffle(_ characters: inout [Character]) throws {
    guard characters.count > 1 else {
      return
    }

    for index in stride(from: characters.count - 1, through: 1, by: -1) {
      let swapIndex = try secureRandomIndex(upperBound: index + 1)
      if swapIndex != index {
        characters.swapAt(index, swapIndex)
      }
    }
  }
}
