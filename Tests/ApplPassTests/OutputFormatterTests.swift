import Foundation
import Testing
@testable import ApplPass

@Suite("Output Formatter Tests")
struct OutputFormatterTests {
  @Test("Table format aligns columns with headers and redacts passwords by default")
  func tableFormatAlignedAndRedactedByDefault() {
    let output = OutputFormatter.format(fixtures, style: .table)
    let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    #expect(lines.count == 4)
    #expect(lines[0].contains("SERVICE"))
    #expect(lines[0].contains("ACCOUNT"))
    #expect(lines[0].contains("CLASS"))
    #expect(lines[1].contains("-+-"))
    #expect(!output.contains("secret-one"))
    #expect(!output.contains("secret-two"))

    let uniqueLineLengths = Set(lines.map(\.count))
    #expect(uniqueLineLengths.count == 1)
  }

  @Test("Table format adds password column when showPasswords is enabled")
  func tableFormatIncludesPasswordsWhenRequested() {
    let output = OutputFormatter.format(fixtures, style: .table, showPasswords: true)
    let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    #expect(lines[0].contains("PASSWORD"))
    #expect(output.contains("secret-one"))
    #expect(output.contains("secret-two"))

    let uniqueLineLengths = Set(lines.map(\.count))
    #expect(uniqueLineLengths.count == 1)
  }
}

private let fixtures = [
  KeychainItem(
    service: "alpha",
    account: "bot",
    password: "secret-one",
    label: "Primary",
    creationDate: nil,
    modificationDate: nil,
    isShared: false,
    sharedGroupName: nil,
    itemClass: .genericPassword
  ),
  KeychainItem(
    service: "beta-long",
    account: "admin-user",
    password: "secret-two",
    label: nil,
    creationDate: nil,
    modificationDate: nil,
    isShared: true,
    sharedGroupName: "Team",
    itemClass: .internetPassword
  ),
]
