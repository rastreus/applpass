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
}

private func assertSendable<T: Sendable>(_: T.Type) {}
