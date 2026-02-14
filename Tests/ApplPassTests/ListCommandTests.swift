import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("List Command Parsing Tests")
struct ListCommandParsingTests {
  @Test("parse maps long options and flags")
  func parseMapsLongOptionsAndFlags() throws {
    let command = try ListCommand.parse(arguments: [
      "--service", "example.com",
      "--account", "bot@example.com",
      "--search", "prod",
      "--format", "json",
      "--shared-only",
      "--show-passwords",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.search == "prod")
    #expect(command.format == .json)
    #expect(command.sharedOnly == true)
    #expect(command.personalOnly == false)
    #expect(command.showPasswords == true)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try ListCommand.parse(arguments: [
      "--service=accounts.example.com",
      "--account=bot@example.com",
      "--search=staging",
      "--format=csv",
      "--personal-only",
    ])

    #expect(command.service == "accounts.example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.search == "staging")
    #expect(command.format == .csv)
    #expect(command.sharedOnly == false)
    #expect(command.personalOnly == true)
    #expect(command.showPasswords == false)
  }

  @Test("parse rejects unknown arguments")
  func parseRejectsUnknownArguments() {
    #expect(throws: ListCommandError.unknownArgument("--invalid")) {
      _ = try ListCommand.parse(arguments: [
        "--service", "example.com",
        "--invalid",
      ])
    }
  }

  @Test("parse rejects invalid format value")
  func parseRejectsInvalidFormat() {
    #expect(throws: ListCommandError.invalidOptionValue(option: "--format", value: "yaml")) {
      _ = try ListCommand.parse(arguments: [
        "--format", "yaml",
      ])
    }
  }
}

@Suite("List Command Filtering Tests")
struct ListCommandFilteringTests {
  @Test("filteredItems keeps only shared items when sharedOnly is enabled")
  func filteredItemsSharedOnly() {
    let items = [
      listFixtureItem(account: "personal@example.com", isShared: false),
      listFixtureItem(account: "shared@example.com", isShared: true),
    ]

    let filtered = ListCommand.filteredItems(
      items,
      search: nil,
      sharedOnly: true,
      personalOnly: false
    )

    #expect(filtered.map(\.account) == ["shared@example.com"])
  }

  @Test("filteredItems keeps only personal items when personalOnly is enabled")
  func filteredItemsPersonalOnly() {
    let items = [
      listFixtureItem(account: "personal@example.com", isShared: false),
      listFixtureItem(account: "shared@example.com", isShared: true),
    ]

    let filtered = ListCommand.filteredItems(
      items,
      search: nil,
      sharedOnly: false,
      personalOnly: true
    )

    #expect(filtered.map(\.account) == ["personal@example.com"])
  }

  @Test("filteredItems applies case-insensitive substring search")
  func filteredItemsAppliesCaseInsensitiveSearch() {
    let items = [
      listFixtureItem(service: "prod.example.com", account: "bot@example.com"),
      listFixtureItem(service: "api.example.com", account: "ops@example.com"),
      listFixtureItem(
        service: "internal.example.com",
        account: "infra@example.com",
        sharedGroupName: "Team Vault"
      ),
    ]

    let filtered = ListCommand.filteredItems(
      items,
      search: "TEAM",
      sharedOnly: false,
      personalOnly: false
    )

    #expect(filtered.count == 1)
    #expect(filtered[0].sharedGroupName == "Team Vault")
  }

  @Test("filteredItems returns empty set when sharedOnly and personalOnly are both enabled")
  func filteredItemsReturnsEmptyForMutuallyExclusiveFlags() {
    let items = [
      listFixtureItem(account: "personal@example.com", isShared: false),
      listFixtureItem(account: "shared@example.com", isShared: true),
    ]

    let filtered = ListCommand.filteredItems(
      items,
      search: nil,
      sharedOnly: true,
      personalOnly: true
    )

    #expect(filtered.isEmpty)
  }
}

@Suite("List Command Behavior Tests")
struct ListCommandBehaviorTests {
  @Test("run calls listPasswords and renders formatted output")
  func runCallsListAndRendersOutput() throws {
    let capturedQuery = SendableBox<KeychainQuery?>(nil)
    let capturedOutput = SendableBox("")
    let capturedStyle = SendableBox<OutputStyle?>(nil)
    let capturedShowPasswords = SendableBox<Bool?>(nil)
    let items = [
      listFixtureItem(service: "example.com", account: "bot@example.com")
    ]
    var command = ListCommand(
      service: "example.com",
      account: "bot@example.com",
      search: nil,
      format: .json,
      sharedOnly: false,
      personalOnly: false,
      showPasswords: true,
      listPasswords: { query in
        capturedQuery.value = query
        return items
      },
      formatOutput: { passedItems, style, showPasswords in
        capturedStyle.value = style
        capturedShowPasswords.value = showPasswords
        #expect(passedItems == items)
        return "formatted-output"
      },
      output: { message in
        capturedOutput.value = message
      }
    )

    try command.run()

    #expect(capturedQuery.value?.service == "example.com")
    #expect(capturedQuery.value?.account == "bot@example.com")
    #expect(capturedQuery.value?.includeShared == true)
    #expect(capturedQuery.value?.itemClass == .genericPassword)
    #expect(capturedStyle.value == .json)
    #expect(capturedShowPasswords.value == true)
    #expect(capturedOutput.value == "formatted-output")
  }

  @Test("run disables shared lookup when personalOnly is enabled")
  func runDisablesSharedLookupWhenPersonalOnlyEnabled() throws {
    let capturedQuery = SendableBox<KeychainQuery?>(nil)
    var command = ListCommand(
      service: nil,
      account: nil,
      search: nil,
      format: .plain,
      sharedOnly: false,
      personalOnly: true,
      showPasswords: false,
      listPasswords: { query in
        capturedQuery.value = query
        return [listFixtureItem(isShared: false)]
      },
      formatOutput: { _, _, _ in
        ""
      },
      output: { _ in
      }
    )

    try command.run()
    #expect(capturedQuery.value?.includeShared == false)
  }

  @Test("run maps keychain errors to user-friendly messages")
  func runMapsKeychainErrorsToUserFriendlyMessages() {
    var command = ListCommand(
      service: nil,
      account: nil,
      search: nil,
      format: .table,
      sharedOnly: false,
      personalOnly: false,
      showPasswords: false,
      listPasswords: { _ in
        throw KeychainError.itemNotFound
      },
      formatOutput: { _, _, _ in
        ""
      },
      output: { _ in
        Issue.record("Output should not be produced on error.")
      }
    )

    #expect(throws: ListCommandError.keychainMessage("Password not found in keychain.")) {
      try command.run()
    }
  }
}

@Suite(.serialized)
struct ListCommandIntegrationTests {
  @Test("run lists multiple items and renders plain output")
  func runListsMultipleItemsAndRendersPlainOutput() throws {
    let keychain = ListCommandTestKeychain()
    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add
    )

    let firstService = "applpass.list.integration.\(UUID().uuidString)"
    let secondService = "applpass.list.integration.\(UUID().uuidString)"
    let firstAccount = "bot-one@example.com"
    let secondAccount = "bot-two@example.com"
    let thirdAccount = "bot-three@example.com"

    try manager.addPassword(
      service: firstService,
      account: firstAccount,
      password: "first-secret",
      label: "List Integration 1",
      sync: false
    )
    try manager.addPassword(
      service: firstService,
      account: secondAccount,
      password: "second-secret",
      label: "List Integration 2",
      sync: true
    )
    try manager.addPassword(
      service: secondService,
      account: thirdAccount,
      password: "third-secret",
      label: "List Integration 3",
      sync: false
    )

    let capturedOutput = SendableBox("")
    var command = ListCommand(
      service: nil,
      account: nil,
      search: nil,
      format: .plain,
      sharedOnly: false,
      personalOnly: false,
      showPasswords: false,
      listPasswords: { query in
        try manager.listPasswords(matching: query)
      },
      formatOutput: { items, style, showPasswords in
        OutputFormatter.format(items, style: style, showPasswords: showPasswords)
      },
      output: { message in
        capturedOutput.value = message
      }
    )

    try command.run()

    let lines = Set(capturedOutput.value.split(separator: "\n").map(String.init))
    let expected = Set([
      "\(firstService)\t\(firstAccount)",
      "\(firstService)\t\(secondAccount)",
      "\(secondService)\t\(thirdAccount)",
    ])

    #expect(lines == expected)
    #expect(lines.count == 3)
  }
}

private func listFixtureItem(
  service: String = "example.com",
  account: String = "bot@example.com",
  password: String = "secret-value",
  isShared: Bool = false,
  sharedGroupName: String? = nil
) -> KeychainItem {
  KeychainItem(
    service: service,
    account: account,
    password: password,
    label: "CLI Bot",
    creationDate: nil,
    modificationDate: nil,
    isShared: isShared,
    sharedGroupName: sharedGroupName,
    itemClass: .genericPassword
  )
}

private final class SendableBox<Value>: @unchecked Sendable {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}

private final class ListCommandTestKeychain: @unchecked Sendable {
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
    let service =
      dictionary[kSecAttrService as String] as? String
      ?? dictionary[kSecAttrServer as String] as? String
    let account = dictionary[kSecAttrAccount as String] as? String
    let synchronizable = dictionary[kSecAttrSynchronizable as String]
    let matchLimit = dictionary[kSecMatchLimit as String]

    let matches = items.filter { item in
      guard item[kSecClass as String] as? String == itemClass else {
        return false
      }

      if let service, item[kSecAttrService as String] as? String != service {
        return false
      }

      if let account, item[kSecAttrAccount as String] as? String != account {
        return false
      }

      if let synchronizable = synchronizable as? NSNumber, synchronizable.boolValue == false {
        return (item[kSecAttrSynchronizable as String] as? Bool) == false
      }

      return true
    }

    guard !matches.isEmpty else {
      return errSecItemNotFound
    }

    if Self.isMultiResultMatchLimit(matchLimit) {
      result?.pointee = matches as CFArray
    } else {
      result?.pointee = matches[0] as CFDictionary
    }

    return errSecSuccess
  }

  private static func isMultiResultMatchLimit(_ matchLimit: Any?) -> Bool {
    if let string = matchLimit as? String {
      return string == (kSecMatchLimitAll as String)
    }

    if let number = matchLimit as? NSNumber {
      return number.intValue > 1
    }

    if let integer = matchLimit as? Int {
      return integer > 1
    }

    return false
  }
}
