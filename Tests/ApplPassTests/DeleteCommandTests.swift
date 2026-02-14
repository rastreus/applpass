import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Delete Command Parsing Tests")
struct DeleteCommandParsingTests {
  @Test("parse maps options and flags")
  func parseMapsOptionsAndFlags() throws {
    let command = try DeleteCommand.parse(arguments: [
      "--service", "example.com",
      "--account", "bot@example.com",
      "--force",
      "--all-accounts",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.force == true)
    #expect(command.allAccounts == true)
  }

  @Test("parse maps short options")
  func parseMapsShortOptions() throws {
    let command = try DeleteCommand.parse(arguments: [
      "-s", "api.example.com",
      "-a", "ops@example.com",
    ])

    #expect(command.service == "api.example.com")
    #expect(command.account == "ops@example.com")
    #expect(command.force == false)
    #expect(command.allAccounts == false)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try DeleteCommand.parse(arguments: [
      "--service=example.com",
      "--account=bot@example.com",
      "--force",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.force == true)
  }

  @Test("parse rejects unknown argument")
  func parseRejectsUnknownArgument() {
    #expect(throws: DeleteCommandError.unknownArgument("--nope")) {
      _ = try DeleteCommand.parse(arguments: ["--service", "example.com", "--nope"])
    }
  }
}

@Suite("Delete Command Behavior Tests")
struct DeleteCommandBehaviorTests {
  @Test("run shows deletion preview and cancels when confirmation declines")
  func runCancelsDeleteWhenConfirmationDeclines() throws {
    let deleteCalls = SendableBox(0)
    let promptValue = SendableBox("")
    let outputLines = SendableBox<[String]>([])

    var command = DeleteCommand(
      service: "example.com",
      account: "bot@example.com",
      force: false,
      allAccounts: false,
      deletePassword: { _ in
        deleteCalls.value += 1
      },
      listPasswords: { _ in
        Issue.record("List path should not be used when --all-accounts is disabled.")
        return []
      },
      confirmDelete: { prompt in
        promptValue.value = prompt
        return false
      },
      output: { message in
        outputLines.value.append(message)
      }
    )

    try command.run()

    #expect(deleteCalls.value == 0)
    #expect(
      promptValue.value
        == "Delete password for service 'example.com' and account 'bot@example.com'? [y/N]: "
    )
    #expect(
      outputLines.value
        == [
          "Will delete password for service 'example.com' and account 'bot@example.com'.",
          "Delete cancelled.",
        ]
    )
  }

  @Test("run bypasses confirmation when force is enabled")
  func runBypassesConfirmationWhenForceEnabled() throws {
    let confirmationCalls = SendableBox(0)
    let deletedQuery = SendableBox<KeychainQuery?>(nil)

    var command = DeleteCommand(
      service: "example.com",
      account: "bot@example.com",
      force: true,
      allAccounts: false,
      deletePassword: { query in
        deletedQuery.value = query
      },
      listPasswords: { _ in
        Issue.record("List path should not be used when --all-accounts is disabled.")
        return []
      },
      confirmDelete: { _ in
        confirmationCalls.value += 1
        return false
      },
      output: { _ in
      }
    )

    try command.run()

    #expect(confirmationCalls.value == 0)
    #expect(deletedQuery.value?.service == "example.com")
    #expect(deletedQuery.value?.account == "bot@example.com")
    #expect(deletedQuery.value?.itemClass == .genericPassword)
  }

  @Test("run deletes multiple accounts when all-accounts is enabled")
  func runDeletesMultipleAccountsWhenAllAccountsEnabled() throws {
    let deletedQueries = SendableBox<[KeychainQuery]>([])
    let confirmationCalls = SendableBox(0)

    var command = DeleteCommand(
      service: "example.com",
      account: nil,
      force: true,
      allAccounts: true,
      deletePassword: { query in
        deletedQueries.value.append(query)
      },
      listPasswords: { query in
        #expect(query.service == "example.com")
        #expect(query.account == nil)

        return [
          deleteFixtureItem(service: "example.com", account: "first@example.com"),
          deleteFixtureItem(service: "example.com", account: "second@example.com"),
        ]
      },
      confirmDelete: { _ in
        confirmationCalls.value += 1
        return false
      },
      output: { _ in
      }
    )

    try command.run()

    #expect(confirmationCalls.value == 0)
    #expect(deletedQueries.value.count == 2)
    #expect(Set(deletedQueries.value.compactMap(\.account)) == ["first@example.com", "second@example.com"])
  }

  @Test("run maps keychain errors to user-friendly message")
  func runMapsKeychainErrorsToUserFriendlyMessage() {
    var command = DeleteCommand(
      service: "example.com",
      account: "bot@example.com",
      force: true,
      allAccounts: false,
      deletePassword: { _ in
        throw KeychainError.authorizationDenied
      },
      listPasswords: { _ in
        []
      },
      confirmDelete: { _ in
        true
      },
      output: { _ in
      }
    )

    #expect(throws: DeleteCommandError.keychainMessage("Access denied. Please allow access when prompted.")) {
      try command.run()
    }
  }
}

@Suite(.serialized)
struct DeleteCommandIntegrationTests {
  @Test("run deletes one account and prints success message")
  func runDeletesSingleAccountAndPrintsSuccessMessage() throws {
    let keychain = DeleteCommandTestKeychain()
    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add,
      delete: keychain.delete
    )
    let service = "applpass.delete.command.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let outputLines = SendableBox<[String]>([])

    try manager.addPassword(
      service: service,
      account: account,
      password: "secret-\(UUID().uuidString)",
      label: "Delete Integration",
      sync: false
    )

    var command = DeleteCommand(
      service: service,
      account: account,
      force: true,
      allAccounts: false,
      deletePassword: { query in
        try manager.deletePassword(for: query)
      },
      listPasswords: { query in
        try manager.listPasswords(matching: query)
      },
      confirmDelete: { _ in
        Issue.record("Confirmation should be skipped when --force is enabled.")
        return true
      },
      output: { message in
        outputLines.value.append(message)
      }
    )

    try command.run()

    #expect(
      outputLines.value
        == [
          "Will delete password for service '\(service)' and account '\(account)'.",
          "Deleted password for service '\(service)' and account '\(account)'.",
        ]
    )

    let query = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 1
    )

    #expect(throws: KeychainError.itemNotFound) {
      _ = try manager.getPassword(for: query)
    }
  }

  @Test("run with all-accounts deletes multiple accounts for one service")
  func runAllAccountsDeletesMultipleForOneService() throws {
    let keychain = DeleteCommandTestKeychain()
    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add,
      delete: keychain.delete
    )
    let targetService = "applpass.delete.command.integration.\(UUID().uuidString)"
    let otherService = "applpass.delete.command.integration.other.\(UUID().uuidString)"
    let firstAccount = "first-\(UUID().uuidString)@example.com"
    let secondAccount = "second-\(UUID().uuidString)@example.com"
    let untouchedAccount = "other-\(UUID().uuidString)@example.com"
    let outputLines = SendableBox<[String]>([])

    try manager.addPassword(
      service: targetService,
      account: firstAccount,
      password: "secret-1",
      label: "Delete Integration 1",
      sync: false
    )
    try manager.addPassword(
      service: targetService,
      account: secondAccount,
      password: "secret-2",
      label: "Delete Integration 2",
      sync: false
    )
    try manager.addPassword(
      service: otherService,
      account: untouchedAccount,
      password: "secret-3",
      label: "Delete Integration 3",
      sync: false
    )

    var command = DeleteCommand(
      service: targetService,
      account: nil,
      force: true,
      allAccounts: true,
      deletePassword: { query in
        try manager.deletePassword(for: query)
      },
      listPasswords: { query in
        try manager.listPasswords(matching: query)
      },
      confirmDelete: { _ in
        Issue.record("Confirmation should be skipped when --force is enabled.")
        return true
      },
      output: { message in
        outputLines.value.append(message)
      }
    )

    try command.run()

    #expect(outputLines.value.contains("Will delete 2 password(s) for service '\(targetService)':"))
    #expect(outputLines.value.contains("- \(firstAccount)"))
    #expect(outputLines.value.contains("- \(secondAccount)"))
    #expect(outputLines.value.contains("Deleted 2 password(s) for service '\(targetService)'."))

    let deletedServiceQuery = KeychainQuery(
      service: targetService,
      account: nil,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 100
    )
    let remainingDeletedServiceItems = try manager.listPasswords(matching: deletedServiceQuery)
    #expect(remainingDeletedServiceItems.isEmpty)

    let untouchedQuery = KeychainQuery(
      service: otherService,
      account: untouchedAccount,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 1
    )
    let untouchedItem = try manager.getPassword(for: untouchedQuery)
    #expect(untouchedItem.service == otherService)
    #expect(untouchedItem.account == untouchedAccount)
  }
}

private func deleteFixtureItem(service: String, account: String) -> KeychainItem {
  KeychainItem(
    service: service,
    account: account,
    password: "secret",
    label: "Delete Fixture",
    creationDate: nil,
    modificationDate: nil,
    isShared: false,
    sharedGroupName: nil,
    itemClass: .genericPassword
  )
}

private final class SendableBox<Value>: @unchecked Sendable {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}

private final class DeleteCommandTestKeychain: @unchecked Sendable {
  private var items: [[String: Any]] = []

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
      $0[kSecClass as String] as? String == itemClass
        && $0[kSecAttrService as String] as? String == service
        && $0[kSecAttrAccount as String] as? String == account
    }) {
      return errSecDuplicateItem
    }

    items.append([
      kSecClass as String: itemClass,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrLabel as String: dictionary[kSecAttrLabel as String] as Any,
      kSecAttrSynchronizable as String:
        (dictionary[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue ?? false,
      kSecValueData as String: passwordData,
    ])

    return errSecSuccess
  }

  func copyMatching(
    _ query: CFDictionary,
    _ result: UnsafeMutablePointer<CFTypeRef?>?
  ) -> OSStatus {
    let dictionary = query as NSDictionary
    let itemClass = dictionary[kSecClass as String] as? String
    let service = dictionary[kSecAttrService as String] as? String
    let account = dictionary[kSecAttrAccount as String] as? String

    let matches = items.filter { item in
      let itemClassMatches = item[kSecClass as String] as? String == itemClass
      let serviceMatches = item[kSecAttrService as String] as? String == service

      if let account {
        return itemClassMatches
          && serviceMatches
          && item[kSecAttrAccount as String] as? String == account
      }

      return itemClassMatches && serviceMatches
    }

    guard !matches.isEmpty else {
      return errSecItemNotFound
    }

    let matchLimit = dictionary[kSecMatchLimit as String] as? String
    if matchLimit == kSecMatchLimitAll as String {
      result?.pointee = matches as CFArray
      return errSecSuccess
    }

    result?.pointee = matches[0] as CFDictionary
    return errSecSuccess
  }

  func delete(_ query: CFDictionary) -> OSStatus {
    let dictionary = query as NSDictionary
    let itemClass = dictionary[kSecClass as String] as? String
    let service = dictionary[kSecAttrService as String] as? String
    let account = dictionary[kSecAttrAccount as String] as? String

    let initialCount = items.count
    items.removeAll { item in
      let classMatches = item[kSecClass as String] as? String == itemClass
      let serviceMatches = item[kSecAttrService as String] as? String == service

      if let account {
        return classMatches
          && serviceMatches
          && item[kSecAttrAccount as String] as? String == account
      }

      return classMatches && serviceMatches
    }

    if items.count == initialCount {
      return errSecItemNotFound
    }

    return errSecSuccess
  }
}
