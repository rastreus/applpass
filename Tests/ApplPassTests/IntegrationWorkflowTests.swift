import Foundation
import Security
import Testing
@testable import ApplPass

@Suite(.serialized)
struct IntegrationWorkflowTests {
}

private final class IntegrationFixture: @unchecked Sendable {
  let keychain = IntegrationTestKeychain()
  lazy var manager = KeychainManager(
    copyMatching: keychain.copyMatching,
    add: keychain.add,
    update: keychain.update,
    delete: keychain.delete
  )
  private var cleanupTargets: [(service: String, account: String)] = []

  func makeUniqueService(_ workflow: String) -> String {
    "applpass.integration.workflow.\(workflow).\(UUID().uuidString)"
  }

  func makeUniqueAccount() -> String {
    "bot-\(UUID().uuidString)@example.com"
  }

  func trackForCleanup(service: String, account: String) {
    cleanupTargets.append((service, account))
  }

  func teardownStatuses() -> [OSStatus] {
    cleanupTargets.map { target in
      keychain.deleteGenericPassword(service: target.service, account: target.account)
    }
  }
}

private final class SendableBox<Value>: @unchecked Sendable {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}

private struct StoredKeychainItem: Sendable {
  let itemClass: String
  let service: String
  let account: String
  let label: String?
  let isShared: Bool
  var passwordData: Data

  func asDictionary() -> [String: Any] {
    [
      kSecClass as String: itemClass,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrLabel as String: label as Any,
      kSecAttrSynchronizable as String: isShared,
      kSecValueData as String: passwordData,
    ]
  }
}

private final class IntegrationTestKeychain: @unchecked Sendable {
  private var items: [StoredKeychainItem] = []

  func add(
    _ query: CFDictionary,
    _ result: UnsafeMutablePointer<CFTypeRef?>?
  ) -> OSStatus {
    _ = result
    let dictionary = query as NSDictionary

    guard
      let itemClass = dictionary[kSecClass as String] as? String,
      let service = dictionary[kSecAttrService as String] as? String,
      let account = dictionary[kSecAttrAccount as String] as? String,
      let passwordData = dictionary[kSecValueData as String] as? Data
    else {
      return errSecParam
    }

    if items.contains(where: {
      $0.itemClass == itemClass
        && $0.service == service
        && $0.account == account
    }) {
      return errSecDuplicateItem
    }

    let isShared =
      (dictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue ?? false
    let label = dictionary[kSecAttrLabel as String] as? String
    items.append(
      StoredKeychainItem(
        itemClass: itemClass,
        service: service,
        account: account,
        label: label,
        isShared: isShared,
        passwordData: passwordData
      )
    )

    return errSecSuccess
  }

  func copyMatching(
    _ query: CFDictionary,
    _ result: UnsafeMutablePointer<CFTypeRef?>?
  ) -> OSStatus {
    let dictionary = query as NSDictionary
    let itemClass = dictionary[kSecClass as String] as? String
    let service =
      dictionary[kSecAttrService as String] as? String
      ?? dictionary[kSecAttrServer as String] as? String
    let account = dictionary[kSecAttrAccount as String] as? String
    let synchronizable = dictionary[kSecAttrSynchronizable as String]

    let matches = items.filter { item in
      guard item.itemClass == itemClass else {
        return false
      }

      if let service, item.service != service {
        return false
      }

      if let account, item.account != account {
        return false
      }

      if let synchronizable = synchronizable as? NSNumber, synchronizable.boolValue == false {
        return item.isShared == false
      }

      return true
    }

    guard !matches.isEmpty else {
      return errSecItemNotFound
    }

    let matchLimit = dictionary[kSecMatchLimit as String] as? String
    if matchLimit == kSecMatchLimitAll as String {
      result?.pointee = matches.map { $0.asDictionary() } as CFArray
    } else {
      result?.pointee = matches[0].asDictionary() as CFDictionary
    }

    return errSecSuccess
  }

  func update(
    _ query: CFDictionary,
    _ attributesToUpdate: CFDictionary
  ) -> OSStatus {
    _ = query
    _ = attributesToUpdate
    return errSecUnimplemented
  }

  func delete(_ query: CFDictionary) -> OSStatus {
    _ = query
    return errSecUnimplemented
  }

  func deleteGenericPassword(service: String, account: String) -> OSStatus {
    let initialCount = items.count
    items.removeAll {
      $0.itemClass == kSecClassGenericPassword as String
        && $0.service == service
        && $0.account == account
    }

    if initialCount == items.count {
      return errSecItemNotFound
    }

    return errSecSuccess
  }
}
