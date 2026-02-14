import Foundation
import Security
import Testing
@testable import ApplPass

@Suite(.serialized)
struct IntegrationWorkflowTests {
  @Test("add then get returns stored password")
  func addThenGetReturnsStoredPassword() throws {
    let fixture = IntegrationFixture()
    defer {
      for status in fixture.teardownStatuses() {
        #expect([errSecSuccess, errSecItemNotFound].contains(status))
      }
    }

    let service = fixture.makeUniqueService("add-get")
    let account = fixture.makeUniqueAccount()
    let password = "secret-\(UUID().uuidString)"
    fixture.trackForCleanup(service: service, account: account)

    let addOutput = SendableBox("")
    var addCommand = AddCommand(
      service: service,
      account: account,
      label: "Workflow Add/Get",
      stdin: false,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { service, account, password, label, sync in
        try fixture.manager.addPassword(
          service: service,
          account: account,
          password: password,
          label: label,
          sync: sync
        )
      },
      generatePassword: { _ in
        Issue.record("Password generation should not be used in this workflow test.")
        return ""
      },
      readStdinLine: {
        Issue.record("stdin input should not be used in this workflow test.")
        return nil
      },
      promptPassword: {
        password
      },
      output: { message in
        addOutput.value = message
      }
    )

    try addCommand.run()
    #expect(
      addOutput.value == "Added password for service '\(service)' and account '\(account)'."
    )

    let getOutput = SendableBox("")
    var getCommand = GetCommand(
      service: service,
      account: account,
      format: .plain,
      clipboard: false,
      valueOnly: true,
      getPassword: { query in
        try fixture.manager.getPassword(for: query)
      },
      formatOutput: { items, style, showPasswords in
        OutputFormatter.format(items, style: style, showPasswords: showPasswords)
      },
      output: { message in
        getOutput.value = message
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard should not be used in this workflow test.")
      }
    )

    try getCommand.run()
    #expect(getOutput.value == password)
  }

  @Test("add then list includes the item in results")
  func addThenListIncludesItemInResults() throws {
    let fixture = IntegrationFixture()
    defer {
      for status in fixture.teardownStatuses() {
        #expect([errSecSuccess, errSecItemNotFound].contains(status))
      }
    }

    let service = fixture.makeUniqueService("add-list")
    let account = fixture.makeUniqueAccount()
    let password = "secret-\(UUID().uuidString)"
    fixture.trackForCleanup(service: service, account: account)

    var addCommand = AddCommand(
      service: service,
      account: account,
      label: "Workflow Add/List",
      stdin: false,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { service, account, password, label, sync in
        try fixture.manager.addPassword(
          service: service,
          account: account,
          password: password,
          label: label,
          sync: sync
        )
      },
      generatePassword: { _ in
        Issue.record("Password generation should not be used in this workflow test.")
        return ""
      },
      readStdinLine: {
        Issue.record("stdin input should not be used in this workflow test.")
        return nil
      },
      promptPassword: {
        password
      },
      output: { _ in
      }
    )

    try addCommand.run()

    let listOutput = SendableBox("")
    var listCommand = ListCommand(
      service: service,
      account: nil,
      search: nil,
      format: .plain,
      sharedOnly: false,
      personalOnly: false,
      showPasswords: false,
      listPasswords: { query in
        try fixture.manager.listPasswords(matching: query)
      },
      formatOutput: { items, style, showPasswords in
        OutputFormatter.format(items, style: style, showPasswords: showPasswords)
      },
      output: { message in
        listOutput.value = message
      }
    )

    try listCommand.run()

    let lines = listOutput.value.split(separator: "\n").map(String.init)
    #expect(lines == ["\(service)\t\(account)"])
  }
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
