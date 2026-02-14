import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Update Command Parsing Tests")
struct UpdateCommandParsingTests {
  @Test("parse maps long options and flags")
  func parseMapsLongOptionsAndFlags() throws {
    let command = try UpdateCommand.parse(arguments: [
      "--service", "github.com",
      "--account", "bot@example.com",
      "--stdin",
      "--generate",
      "--force",
      "--length", "48",
    ])

    #expect(command.service == "github.com")
    #expect(command.account == "bot@example.com")
    #expect(command.stdin == true)
    #expect(command.generate == true)
    #expect(command.force == true)
    #expect(command.length == 48)
  }

  @Test("parse maps short options and flags")
  func parseMapsShortOptionsAndFlags() throws {
    let command = try UpdateCommand.parse(arguments: [
      "-s", "api.openai.com",
      "-a", "bot@example.com",
      "-g",
      "-n", "64",
    ])

    #expect(command.service == "api.openai.com")
    #expect(command.account == "bot@example.com")
    #expect(command.stdin == false)
    #expect(command.generate == true)
    #expect(command.force == false)
    #expect(command.length == 64)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try UpdateCommand.parse(arguments: [
      "--service=example.com",
      "--account=bot@example.com",
      "--length=72",
      "--force",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.length == 72)
    #expect(command.force == true)
  }

  @Test("parse rejects unknown arguments")
  func parseRejectsUnknownArguments() {
    #expect(throws: UpdateCommandError.unknownArgument("--bad-flag")) {
      _ = try UpdateCommand.parse(arguments: [
        "--service", "example.com",
        "--account", "bot@example.com",
        "--bad-flag",
      ])
    }
  }

  @Test("parse rejects invalid length values")
  func parseRejectsInvalidLengthValues() {
    #expect(throws: UpdateCommandError.invalidOptionValue(option: "--length", value: "zero")) {
      _ = try UpdateCommand.parse(arguments: ["--length", "zero"])
    }

    #expect(throws: UpdateCommandError.invalidOptionValue(option: "--length", value: "0")) {
      _ = try UpdateCommand.parse(arguments: ["--length", "0"])
    }
  }
}

@Suite("Update Command Behavior Tests")
struct UpdateCommandBehaviorTests {
  @Test("run cancels update when confirmation declines")
  func runCancelsUpdateWhenConfirmationDeclines() throws {
    let updateCalled = SendableBox(false)
    let outputMessage = SendableBox("")

    var command = UpdateCommand(
      service: "example.com",
      account: "bot@example.com",
      stdin: true,
      generate: false,
      force: false,
      length: 32,
      updatePassword: { _, _ in
        updateCalled.value = true
      },
      generatePassword: { _ in
        Issue.record("Password generation should not be used for --stdin.")
        return ""
      },
      readStdinLine: {
        "stdin-secret"
      },
      promptPassword: {
        Issue.record("Interactive password should not be used for --stdin.")
        return ""
      },
      confirmUpdate: { service, account in
        #expect(service == "example.com")
        #expect(account == "bot@example.com")
        return false
      },
      output: { message in
        outputMessage.value = message
      }
    )

    try command.run()

    #expect(updateCalled.value == false)
    #expect(outputMessage.value == "Update cancelled.")
  }

  @Test("run bypasses confirmation when force is enabled")
  func runBypassesConfirmationWhenForceIsEnabled() throws {
    let confirmationCalls = SendableBox(0)
    let capturedPassword = SendableBox("")

    var command = UpdateCommand(
      service: "example.com",
      account: "bot@example.com",
      stdin: true,
      generate: false,
      force: true,
      length: 32,
      updatePassword: { _, password in
        capturedPassword.value = password
      },
      generatePassword: { _ in
        Issue.record("Password generation should not be used for --stdin.")
        return ""
      },
      readStdinLine: {
        "stdin-secret"
      },
      promptPassword: {
        Issue.record("Interactive password should not be used for --stdin.")
        return ""
      },
      confirmUpdate: { _, _ in
        confirmationCalls.value += 1
        return false
      },
      output: { _ in
      }
    )

    try command.run()

    #expect(confirmationCalls.value == 0)
    #expect(capturedPassword.value == "stdin-secret")
  }

  @Test("run maps keychain errors to user-friendly messages")
  func runMapsKeychainErrorsToUserFriendlyMessages() {
    var command = UpdateCommand(
      service: "example.com",
      account: "bot@example.com",
      stdin: true,
      generate: false,
      force: true,
      length: 32,
      updatePassword: { _, _ in
        throw KeychainError.itemNotFound
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        "stdin-secret"
      },
      promptPassword: {
        ""
      },
      confirmUpdate: { _, _ in
        true
      },
      output: { _ in
        Issue.record("Output should not be produced on keychain errors.")
      }
    )

    #expect(throws: UpdateCommandError.keychainMessage("Password not found in keychain.")) {
      try command.run()
    }
  }

  @Test("run uses PasswordGenerator when generate is enabled")
  func runUsesPasswordGeneratorWhenGenerateIsEnabled() throws {
    let capturedLength = SendableBox<Int?>(nil)
    let capturedPassword = SendableBox("")

    var command = UpdateCommand(
      service: "example.com",
      account: "bot@example.com",
      stdin: false,
      generate: true,
      force: true,
      length: 56,
      updatePassword: { _, password in
        capturedPassword.value = password
      },
      generatePassword: { length in
        capturedLength.value = length
        return "generated-secret"
      },
      readStdinLine: {
        Issue.record("stdin should not be used for generated passwords.")
        return nil
      },
      promptPassword: {
        Issue.record("Interactive password should not be used for generated passwords.")
        return ""
      },
      confirmUpdate: { _, _ in
        true
      },
      output: { _ in
      }
    )

    try command.run()

    #expect(capturedLength.value == 56)
    #expect(capturedPassword.value == "generated-secret")
  }

  @Test("run maps confirmation prompt failures")
  func runMapsConfirmationPromptFailures() {
    var command = UpdateCommand(
      service: "example.com",
      account: "bot@example.com",
      stdin: true,
      generate: false,
      force: false,
      length: 32,
      updatePassword: { _, _ in
        Issue.record("Keychain update should not be called when confirmation fails.")
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        "stdin-secret"
      },
      promptPassword: {
        ""
      },
      confirmUpdate: { _, _ in
        throw UpdateCommandError.confirmationPromptRequiresTTY
      },
      output: { _ in
      }
    )

    #expect(throws: UpdateCommandError.confirmationPromptRequiresTTY) {
      try command.run()
    }
  }
}

@Suite(.serialized)
struct UpdateCommandIntegrationTests {
  @Test("run updates an existing item and prints success message")
  func runUpdatesExistingItemAndPrintsSuccessMessage() throws {
    let keychain = UpdateCommandTestKeychain()
    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add,
      update: keychain.update
    )

    let service = "applpass.update.command.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let outputMessage = SendableBox("")

    try manager.addPassword(
      service: service,
      account: account,
      password: "original-secret",
      label: "Update Command Integration",
      sync: false
    )

    var command = UpdateCommand(
      service: service,
      account: account,
      stdin: false,
      generate: false,
      force: true,
      length: 32,
      updatePassword: { query, password in
        try manager.updatePassword(for: query, newPassword: password)
      },
      generatePassword: { _ in
        Issue.record("Password generation should not be used in this integration test.")
        return ""
      },
      readStdinLine: {
        Issue.record("stdin should not be used in this integration test.")
        return nil
      },
      promptPassword: {
        "updated-secret"
      },
      confirmUpdate: { _, _ in
        Issue.record("Confirmation should be bypassed when --force is enabled.")
        return true
      },
      output: { message in
        outputMessage.value = message
      }
    )

    try command.run()

    #expect(
      outputMessage.value
        == "Updated password for service '\(service)' and account '\(account)'."
    )

    let query = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: true,
      itemClass: .genericPassword,
      limit: 1
    )
    let item = try manager.getPassword(for: query)

    #expect(item.service == service)
    #expect(item.account == account)
    #expect(item.password == "updated-secret")
    #expect(item.label == "Update Command Integration")
  }
}

private final class SendableBox<Value>: @unchecked Sendable {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}

private final class UpdateCommandTestKeychain: @unchecked Sendable {
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

  func update(
    _ query: CFDictionary,
    _ attributesToUpdate: CFDictionary
  ) -> OSStatus {
    let queryDictionary = query as NSDictionary
    let itemClass = queryDictionary[kSecClass as String] as? String
    let service = queryDictionary[kSecAttrService as String] as? String
    let account = queryDictionary[kSecAttrAccount as String] as? String

    guard
      let itemIndex = items.firstIndex(where: {
        $0[kSecClass as String] as? String == itemClass
          && $0[kSecAttrService as String] as? String == service
          && $0[kSecAttrAccount as String] as? String == account
      })
    else {
      return errSecItemNotFound
    }

    let updateDictionary = attributesToUpdate as NSDictionary
    guard let passwordData = updateDictionary[kSecValueData as String] as? Data else {
      return errSecParam
    }

    items[itemIndex][kSecValueData as String] = passwordData
    return errSecSuccess
  }
}
