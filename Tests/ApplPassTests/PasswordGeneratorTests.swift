import Testing
@testable import ApplPass

@Suite("Password Generator Tests")
struct PasswordGeneratorTests {
  private static let symbolCharacters = Set("!@#$%^&*()-_=+[]{};:,.<>?/\\|~`")

  @Test("generate uses default length of 32 characters")
  func generateUsesDefaultLength() throws {
    let password = try PasswordGenerator.generate()
    #expect(password.count == 32)
  }

  @Test("generate returns requested length", arguments: [16, 32, 64, 128])
  func generateReturnsRequestedLength(length: Int) throws {
    let password = try PasswordGenerator.generate(length: length)
    #expect(password.count == length)
  }

  @Test(
    "generate excludes disabled character sets",
    arguments: [
      (false, true, false, false),
      (false, false, true, false),
      (false, false, false, true),
      (true, false, false, false),
    ]
  )
  func generateExcludesDisabledCharacterSets(
    includeSymbols: Bool,
    includeUppercase: Bool,
    includeLowercase: Bool,
    includeDigits: Bool
  ) throws {
    let password = try PasswordGenerator.generate(
      length: 128,
      includeSymbols: includeSymbols,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeDigits: includeDigits
    )

    #expect(password.allSatisfy { character in
      switch character {
      case _ where character.isUppercase:
        return includeUppercase
      case _ where character.isLowercase:
        return includeLowercase
      case _ where character.isNumber:
        return includeDigits
      default:
        return includeSymbols
      }
    })
  }

  @Test("generate includes at least one character from each enabled set")
  func generateIncludesCharactersFromEachEnabledSet() throws {
    for _ in 0..<256 {
      let password = try PasswordGenerator.generate(
        length: 32,
        includeSymbols: true,
        includeUppercase: true,
        includeLowercase: true,
        includeDigits: true
      )

      #expect(password.contains(where: { $0.isUppercase }))
      #expect(password.contains(where: { $0.isLowercase }))
      #expect(password.contains(where: { $0.isNumber }))
      #expect(password.contains(where: { Self.symbolCharacters.contains($0) }))
    }
  }
}
