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

  @Test("JSON format emits valid array and redacts passwords by default")
  func jsonFormatIsValidAndRedactedByDefault() throws {
    let output = OutputFormatter.format(fixtures, style: .json)
    #expect(!output.contains("secret-one"))
    #expect(!output.contains("secret-two"))

    let records = try parseJSONRecords(from: output)
    #expect(records.count == 2)
    #expect(records.allSatisfy { $0["password"] == nil })
    #expect(records.map { $0["service"] as? String } == ["alpha", "beta-long"])
  }

  @Test("JSON format escapes special characters and includes password when requested")
  func jsonFormatEscapesSpecialCharacters() throws {
    let special = KeychainItem(
      service: "svc\"line\nbreak",
      account: "user\\account",
      password: "pass,\"line\nbreak",
      label: "ops,team",
      creationDate: nil,
      modificationDate: nil,
      isShared: true,
      sharedGroupName: "Team \"Blue\"",
      itemClass: .internetPassword
    )

    let output = OutputFormatter.format([special], style: .json, showPasswords: true)
    let records = try parseJSONRecords(from: output)

    #expect(records.count == 1)
    #expect(records[0]["service"] as? String == special.service)
    #expect(records[0]["account"] as? String == special.account)
    #expect(records[0]["password"] as? String == special.password)
    #expect(records[0]["sharedGroupName"] as? String == special.sharedGroupName)
  }

  @Test("CSV format applies RFC 4180 escaping and redacts passwords by default")
  func csvFormatEscapesAndRedactsByDefault() {
    let special = KeychainItem(
      service: "svc,\"one\"",
      account: "line\nbreak",
      password: "secret-csv",
      label: "ops,team",
      creationDate: nil,
      modificationDate: nil,
      isShared: true,
      sharedGroupName: "Team",
      itemClass: .internetPassword
    )

    let output = OutputFormatter.format([special], style: .csv)
    let lines = output.components(separatedBy: "\r\n")

    #expect(lines.count == 2)
    #expect(lines[0].contains("SERVICE"))
    #expect(!lines[0].contains("PASSWORD"))
    #expect(lines[1].contains("\"svc,\"\"one\"\"\""))
    #expect(lines[1].contains("\"line\nbreak\""))
    #expect(lines[1].contains("\"ops,team\""))
    #expect(!output.contains("secret-csv"))
  }

  @Test("CSV format adds password column when showPasswords is enabled")
  func csvFormatIncludesPasswordsWhenRequested() {
    let output = OutputFormatter.format(fixtures, style: .csv, showPasswords: true)
    let lines = output.components(separatedBy: "\r\n")

    #expect(lines[0].contains("PASSWORD"))
    #expect(output.contains("secret-one"))
    #expect(output.contains("secret-two"))
  }

  @Test("Plain format outputs value-only rows for piping and redacts passwords by default")
  func plainFormatValueOnlyWithoutPasswordsByDefault() {
    let output = OutputFormatter.format(fixtures, style: .plain)
    let lines = output.components(separatedBy: "\n")

    #expect(lines == ["alpha\tbot", "beta-long\tadmin-user"])
    #expect(!output.contains("SERVICE"))
    #expect(!output.contains("secret-one"))
    #expect(!output.contains("secret-two"))
  }

  @Test("Plain format includes password field when showPasswords is enabled")
  func plainFormatIncludesPasswordsWhenRequested() {
    let output = OutputFormatter.format(fixtures, style: .plain, showPasswords: true)
    let lines = output.components(separatedBy: "\n")

    #expect(lines == ["alpha\tbot\tsecret-one", "beta-long\tadmin-user\tsecret-two"])
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

private func parseJSONRecords(from json: String) throws -> [[String: Any]] {
  guard let data = json.data(using: .utf8) else {
    Issue.record("Expected UTF-8 JSON output")
    return []
  }

  let object = try JSONSerialization.jsonObject(with: data)
  guard let records = object as? [[String: Any]] else {
    Issue.record("Expected top-level JSON array of dictionaries")
    return []
  }

  return records
}
