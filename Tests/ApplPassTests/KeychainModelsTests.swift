import Foundation
import Testing
@testable import ApplPass

@Suite("Keychain Models Tests")
struct KeychainModelsTests {
  @Test("Core data models conform to Sendable")
  func modelsConformToSendable() {
    assertSendable(ItemClass.self)
    assertSendable(KeychainItem.self)
    assertSendable(KeychainQuery.self)
    assertSendable(KeychainError.self)
  }

  @Test("KeychainItem supports Codable round-trip")
  func keychainItemCodableRoundTrip() throws {
    let timestamp = Date(timeIntervalSince1970: 1_739_193_615)
    let item = KeychainItem(
      service: "github.com",
      account: "bot@example.com",
      password: "secret-value",
      label: "GitHub Bot",
      creationDate: timestamp,
      modificationDate: timestamp,
      isShared: true,
      sharedGroupName: "Team Credentials",
      itemClass: .internetPassword
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(item)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(KeychainItem.self, from: data)
    #expect(decoded == item)
  }

  @Test("KeychainQuery supports Codable round-trip")
  func keychainQueryCodableRoundTrip() throws {
    let query = KeychainQuery(
      service: "api.openai.com",
      account: nil,
      domain: "openai.com",
      includeShared: false,
      itemClass: .genericPassword,
      limit: 25
    )

    let data = try JSONEncoder().encode(query)
    let decoded = try JSONDecoder().decode(KeychainQuery.self, from: data)
    #expect(decoded == query)
  }

  @Test("KeychainError provides user-facing descriptions")
  func keychainErrorDescriptions() {
    let invalidParameter = KeychainError.invalidParameter("service cannot be empty")
    #expect(invalidParameter.errorDescription == "Invalid parameter: service cannot be empty")
    #expect(KeychainError.itemNotFound.errorDescription == "Password not found in keychain.")
  }
}

private func assertSendable<T: Sendable>(_: T.Type) {}
