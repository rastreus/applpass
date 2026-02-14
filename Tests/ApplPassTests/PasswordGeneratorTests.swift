import Testing
@testable import ApplPass

@Suite("Password Generator Tests")
struct PasswordGeneratorTests {
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
}
