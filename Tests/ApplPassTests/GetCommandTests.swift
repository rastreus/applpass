import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Get Command Parsing Tests")
struct GetCommandParsingTests {
  @Test("parse maps long options and flags")
  func parseMapsLongOptionsAndFlags() throws {
    let command = try GetCommand.parse(arguments: [
      "--service", "github.com",
      "--account", "bot@example.com",
      "--format", "json",
      "--clipboard",
      "--value-only",
    ])

    #expect(command.service == "github.com")
    #expect(command.account == "bot@example.com")
    #expect(command.format == .json)
    #expect(command.clipboard == true)
    #expect(command.valueOnly == true)
  }

  @Test("parse maps short options and flags")
  func parseMapsShortOptionsAndFlags() throws {
    let command = try GetCommand.parse(arguments: [
      "-s", "api.openai.com",
      "-a", "bot@example.com",
      "-f", "plain",
      "-c",
      "-v",
    ])

    #expect(command.service == "api.openai.com")
    #expect(command.account == "bot@example.com")
    #expect(command.format == .plain)
    #expect(command.clipboard == true)
    #expect(command.valueOnly == true)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try GetCommand.parse(arguments: [
      "--service=example.com",
      "--account=bot@example.com",
      "--format=csv",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.format == .csv)
  }

  @Test("parse rejects unknown arguments")
  func parseRejectsUnknownArguments() {
    #expect(throws: GetCommandError.unknownArgument("--bad-flag")) {
      _ = try GetCommand.parse(arguments: [
        "--service", "example.com",
        "--account", "bot@example.com",
        "--bad-flag",
      ])
    }
  }

  @Test("parse rejects invalid format value")
  func parseRejectsInvalidFormat() {
    #expect(throws: GetCommandError.invalidOptionValue(option: "--format", value: "yaml")) {
      _ = try GetCommand.parse(arguments: [
        "--service", "example.com",
        "--account", "bot@example.com",
        "--format", "yaml",
      ])
    }
  }
}

@Suite("Get Command Behavior Tests")
struct GetCommandBehaviorTests {
  @Test("run formats output when value-only and clipboard are disabled")
  func runFormatsOutputWhenNotValueOnlyOrClipboard() throws {
    let item = fixtureItem()
    let capturedOutput = SendableBox("")
    let formatterCallCount = SendableBox(0)
    var command = GetCommand(
      service: "example.com",
      account: "bot@example.com",
      format: .json,
      clipboard: false,
      valueOnly: false,
      getPassword: { query in
        #expect(query.service == "example.com")
        #expect(query.account == "bot@example.com")
        return item
      },
      formatOutput: { items, style, showPasswords in
        formatterCallCount.value += 1
        #expect(items == [item])
        #expect(style == .json)
        #expect(showPasswords == true)
        return "formatted-output"
      },
      output: { message in
        capturedOutput.value = message
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard path should not be used.")
      }
    )

    try command.run()
    #expect(formatterCallCount.value == 1)
    #expect(capturedOutput.value == "formatted-output")
  }

  @Test("run outputs only password when value-only is enabled")
  func runOutputsOnlyPasswordWhenValueOnlyEnabled() throws {
    let item = fixtureItem(password: "value-only-secret")
    let capturedOutput = SendableBox("")
    let capturedQueries = SendableBox<[KeychainQuery]>([])
    var command = GetCommand(
      service: "example.com",
      account: "bot@example.com",
      format: .table,
      clipboard: false,
      valueOnly: true,
      getPassword: { query in
        capturedQueries.value.append(query)
        return item
      },
      formatOutput: { _, _, _ in
        Issue.record("Formatter should not be used for --value-only.")
        return ""
      },
      output: { message in
        capturedOutput.value = message
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard path should not be used.")
      }
    )

    try command.run()
    #expect(capturedOutput.value == "value-only-secret")
    #expect(capturedQueries.value.map(\.itemClass) == [.internetPassword])
  }

  @Test("run falls back to generic-password query when internet-password is not found")
  func runFallsBackToGenericPasswordWhenInternetPasswordIsMissing() throws {
    let capturedOutput = SendableBox("")
    let capturedQueries = SendableBox<[KeychainQuery]>([])
    let genericItem = KeychainItem(
      service: "example.com",
      account: "bot@example.com",
      password: "generic-secret",
      label: "CLI Bot",
      creationDate: nil,
      modificationDate: nil,
      isShared: false,
      sharedGroupName: nil,
      itemClass: .genericPassword
    )
    var command = GetCommand(
      service: "example.com",
      account: "bot@example.com",
      format: .plain,
      clipboard: false,
      valueOnly: true,
      getPassword: { query in
        capturedQueries.value.append(query)
        if query.itemClass == .internetPassword {
          throw KeychainError.itemNotFound
        }
        return genericItem
      },
      formatOutput: { _, _, _ in
        Issue.record("Formatter should not be used for --value-only.")
        return ""
      },
      output: { message in
        capturedOutput.value = message
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard path should not be used.")
      }
    )

    try command.run()

    #expect(capturedQueries.value.map(\.itemClass) == [.internetPassword, .genericPassword])
    #expect(capturedOutput.value == "generic-secret")
  }

  @Test("run copies password to clipboard when clipboard flag is enabled")
  func runCopiesPasswordToClipboardWhenEnabled() throws {
    let item = fixtureItem(password: "clipboard-secret")
    let copiedValue = SendableBox("")
    let outputMessage = SendableBox("")
    var command = GetCommand(
      service: "example.com",
      account: "bot@example.com",
      format: .plain,
      clipboard: true,
      valueOnly: false,
      getPassword: { _ in
        item
      },
      formatOutput: { _, _, _ in
        Issue.record("Formatter should not be used for --clipboard.")
        return ""
      },
      output: { message in
        outputMessage.value = message
      },
      copyToClipboard: { value in
        copiedValue.value = value
      }
    )

    try command.run()
    #expect(copiedValue.value == "clipboard-secret")
    #expect(outputMessage.value == "Password copied to clipboard.")
  }

  @Test("run maps keychain errors to user-friendly messages")
  func runMapsKeychainErrorsToUserFriendlyMessages() {
    var command = GetCommand(
      service: "missing.example.com",
      account: "bot@example.com",
      format: .plain,
      clipboard: false,
      valueOnly: false,
      getPassword: { _ in
        throw KeychainError.itemNotFound
      },
      formatOutput: { _, _, _ in
        ""
      },
      output: { _ in
        Issue.record("Output should not be produced on error.")
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard path should not be used.")
      }
    )

    #expect(throws: GetCommandError.keychainMessage("Password not found in keychain.")) {
      try command.run()
    }
  }

  @Test("run maps clipboard failures to user-friendly messages")
  func runMapsClipboardFailuresToUserFriendlyMessages() {
    let item = fixtureItem(password: "clipboard-secret")
    var command = GetCommand(
      service: "example.com",
      account: "bot@example.com",
      format: .plain,
      clipboard: true,
      valueOnly: false,
      getPassword: { _ in
        item
      },
      formatOutput: { _, _, _ in
        ""
      },
      output: { _ in
        Issue.record("Output should not be produced when clipboard fails.")
      },
      copyToClipboard: { _ in
        throw KeychainError.operationFailed(errSecNotAvailable)
      }
    )

    #expect(throws: GetCommandError.clipboardFailed) {
      try command.run()
    }
  }
}

@Suite(.serialized)
struct GetCommandIntegrationTests {
  @Test("add item then get command returns formatted output")
  func addItemThenGetCommandReturnsFormattedOutput() throws {
    let keychain = GetCommandTestKeychain()
    let service = "applpass.get.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let password = "secret-\(UUID().uuidString)"

    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add
    )

    try manager.addPassword(
      service: service,
      account: account,
      password: password,
      label: "ApplPass Get Integration",
      sync: false
    )

    let renderedOutput = SendableBox("")
    var command = GetCommand(
      service: service,
      account: account,
      format: .plain,
      clipboard: false,
      valueOnly: false,
      getPassword: { query in
        try manager.getPassword(for: query)
      },
      formatOutput: { items, style, showPasswords in
        OutputFormatter.format(items, style: style, showPasswords: showPasswords)
      },
      output: { message in
        renderedOutput.value = message
      },
      copyToClipboard: { _ in
        Issue.record("Clipboard path should not be used.")
      }
    )

    try command.run()
    #expect(renderedOutput.value == "\(service)\t\(account)\t\(password)")
  }
}

private func fixtureItem(password: String = "secret-value") -> KeychainItem {
  KeychainItem(
    service: "example.com",
    account: "bot@example.com",
    password: password,
    label: "CLI Bot",
    creationDate: nil,
    modificationDate: nil,
    isShared: false,
    sharedGroupName: nil,
    itemClass: .internetPassword
  )
}

private final class SendableBox<Value>: @unchecked Sendable {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}

private final class GetCommandTestKeychain: @unchecked Sendable {
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

    guard
      let match = items.first(where: {
        $0[kSecClass as String] as? String == itemClass
          && $0[kSecAttrService as String] as? String == service
          && $0[kSecAttrAccount as String] as? String == account
      })
    else {
      return errSecItemNotFound
    }

    result?.pointee = match as CFDictionary
    return errSecSuccess
  }
}
