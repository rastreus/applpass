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
