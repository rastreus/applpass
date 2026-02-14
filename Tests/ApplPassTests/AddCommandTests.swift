import Foundation
import Security
import Testing
@testable import ApplPass

@Suite("Add Command Parsing Tests")
struct AddCommandParsingTests {
  @Test("parse maps long options and flags")
  func parseMapsLongOptionsAndFlags() throws {
    let command = try AddCommand.parse(arguments: [
      "--service", "github.com",
      "--account", "bot@example.com",
      "--label", "CLI Bot",
      "--stdin",
      "--generate",
      "--sync",
      "--length", "48",
    ])

    #expect(command.service == "github.com")
    #expect(command.account == "bot@example.com")
    #expect(command.label == "CLI Bot")
    #expect(command.stdin == true)
    #expect(command.generate == true)
    #expect(command.sync == true)
    #expect(command.length == 48)
  }

  @Test("parse maps short options and flags")
  func parseMapsShortOptionsAndFlags() throws {
    let command = try AddCommand.parse(arguments: [
      "-s", "api.openai.com",
      "-a", "bot@example.com",
      "-l", "Bot API",
      "-g",
      "-n", "64",
    ])

    #expect(command.service == "api.openai.com")
    #expect(command.account == "bot@example.com")
    #expect(command.label == "Bot API")
    #expect(command.stdin == false)
    #expect(command.generate == true)
    #expect(command.sync == false)
    #expect(command.length == 64)
  }

  @Test("parse supports equals syntax")
  func parseSupportsEqualsSyntax() throws {
    let command = try AddCommand.parse(arguments: [
      "--service=example.com",
      "--account=bot@example.com",
      "--label=CI Bot",
      "--length=72",
      "--sync",
    ])

    #expect(command.service == "example.com")
    #expect(command.account == "bot@example.com")
    #expect(command.label == "CI Bot")
    #expect(command.length == 72)
    #expect(command.sync == true)
  }

  @Test("parse rejects unknown arguments")
  func parseRejectsUnknownArguments() {
    #expect(throws: AddCommandError.unknownArgument("--bad-flag")) {
      _ = try AddCommand.parse(arguments: [
        "--service", "example.com",
        "--account", "bot@example.com",
        "--bad-flag",
      ])
    }
  }

  @Test("parse rejects invalid length values")
  func parseRejectsInvalidLengthValues() {
    #expect(throws: AddCommandError.invalidOptionValue(option: "--length", value: "zero")) {
      _ = try AddCommand.parse(arguments: ["--length", "zero"])
    }

    #expect(throws: AddCommandError.invalidOptionValue(option: "--length", value: "0")) {
      _ = try AddCommand.parse(arguments: ["--length", "0"])
    }
  }
}

@Suite("Add Command Behavior Tests")
struct AddCommandBehaviorTests {
  @Test("run reads password from stdin when --stdin is enabled")
  func runReadsPasswordFromStdin() throws {
    let capturedOutput = SendableBox("")
    let capturedPassword = SendableBox("")
    let capturedLabel = SendableBox("")
    let capturedSync = SendableBox<Bool?>(nil)

    var command = AddCommand(
      service: "example.com",
      account: "bot@example.com",
      label: "CLI Bot",
      stdin: true,
      generate: false,
      sync: true,
      length: 32,
      addPassword: { _, _, password, label, sync in
        capturedPassword.value = password
        capturedLabel.value = label
        capturedSync.value = sync
      },
      generatePassword: { _ in
        Issue.record("Password generation should not be used for --stdin.")
        return ""
      },
      readStdinLine: {
        "stdin-secret"
      },
      promptPassword: {
        Issue.record("Interactive prompt should not be used for --stdin.")
        return ""
      },
      output: { message in
        capturedOutput.value = message
      }
    )

    try command.run()

    #expect(capturedPassword.value == "stdin-secret")
    #expect(capturedLabel.value == "CLI Bot")
    #expect(capturedSync.value == true)
    #expect(
      capturedOutput.value
        == "Added password for service 'example.com' and account 'bot@example.com'."
    )
  }

  @Test("run prompts for password interactively when no input flags are provided")
  func runPromptsInteractivelyWithoutInputFlags() throws {
    let capturedPassword = SendableBox("")
    var command = AddCommand(
      service: "interactive.example.com",
      account: "bot@example.com",
      label: nil,
      stdin: false,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { service, _, password, label, _ in
        capturedPassword.value = password
        #expect(service == "interactive.example.com")
        #expect(label == "interactive.example.com")
      },
      generatePassword: { _ in
        Issue.record("Password generation should not be used for interactive input.")
        return ""
      },
      readStdinLine: {
        Issue.record("stdin should not be used for interactive input.")
        return nil
      },
      promptPassword: {
        "prompt-secret"
      },
      output: { _ in
      }
    )

    try command.run()
    #expect(capturedPassword.value == "prompt-secret")
  }

  @Test("run uses PasswordGenerator path when --generate is enabled")
  func runUsesPasswordGeneratorPath() throws {
    let capturedLength = SendableBox<Int?>(nil)
    let capturedPassword = SendableBox("")
    var command = AddCommand(
      service: "generate.example.com",
      account: "bot@example.com",
      label: "Generated Label",
      stdin: false,
      generate: true,
      sync: false,
      length: 64,
      addPassword: { _, _, password, _, _ in
        capturedPassword.value = password
      },
      generatePassword: { length in
        capturedLength.value = length
        return "generated-secret"
      },
      readStdinLine: {
        Issue.record("stdin should not be used when generating passwords.")
        return nil
      },
      promptPassword: {
        Issue.record("Interactive prompt should not be used when generating passwords.")
        return ""
      },
      output: { _ in
      }
    )

    try command.run()

    #expect(capturedLength.value == 64)
    #expect(capturedPassword.value == "generated-secret")
  }

  @Test("run validates required service and account")
  func runValidatesRequiredServiceAndAccount() {
    var missingService = AddCommand(
      service: nil,
      account: "bot@example.com",
      label: nil,
      stdin: true,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { _, _, _, _, _ in
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        "secret"
      },
      promptPassword: {
        ""
      },
      output: { _ in
      }
    )

    #expect(throws: AddCommandError.missingRequiredOption("--service")) {
      try missingService.run()
    }

    var missingAccount = AddCommand(
      service: "example.com",
      account: "   ",
      label: nil,
      stdin: true,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { _, _, _, _, _ in
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        "secret"
      },
      promptPassword: {
        ""
      },
      output: { _ in
      }
    )

    #expect(throws: AddCommandError.missingRequiredOption("--account")) {
      try missingAccount.run()
    }
  }

  @Test("run rejects conflicting --stdin and --generate flags")
  func runRejectsConflictingInputFlags() {
    var command = AddCommand(
      service: "example.com",
      account: "bot@example.com",
      label: nil,
      stdin: true,
      generate: true,
      sync: false,
      length: 32,
      addPassword: { _, _, _, _, _ in
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        "secret"
      },
      promptPassword: {
        "secret"
      },
      output: { _ in
      }
    )

    #expect(throws: AddCommandError.conflictingInputModes) {
      try command.run()
    }
  }

  @Test("run rejects empty stdin password")
  func runRejectsEmptyStdinPassword() {
    var command = AddCommand(
      service: "example.com",
      account: "bot@example.com",
      label: nil,
      stdin: true,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { _, _, _, _, _ in
        Issue.record("Keychain should not be called for empty password.")
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        ""
      },
      promptPassword: {
        ""
      },
      output: { _ in
      }
    )

    #expect(throws: AddCommandError.emptyPasswordInput) {
      try command.run()
    }
  }

  @Test("run maps keychain errors to user-friendly messages")
  func runMapsKeychainErrorsToUserFriendlyMessages() {
    var command = AddCommand(
      service: "example.com",
      account: "bot@example.com",
      label: nil,
      stdin: true,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { _, _, _, _, _ in
        throw KeychainError.duplicateItem
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        "secret"
      },
      promptPassword: {
        ""
      },
      output: { _ in
        Issue.record("Output should not be produced on keychain errors.")
      }
    )

    #expect(throws: AddCommandError.keychainMessage("A password with these credentials already exists.")) {
      try command.run()
    }
  }

  @Test("run maps password generation failures to user-friendly messages")
  func runMapsPasswordGenerationFailures() {
    var command = AddCommand(
      service: "example.com",
      account: "bot@example.com",
      label: nil,
      stdin: false,
      generate: true,
      sync: false,
      length: 1,
      addPassword: { _, _, _, _, _ in
        Issue.record("Keychain should not be called on generation failure.")
      },
      generatePassword: { _ in
        throw PasswordGeneratorError.lengthTooShortForEnabledSets
      },
      readStdinLine: {
        nil
      },
      promptPassword: {
        ""
      },
      output: { _ in
      }
    )

    #expect(
      throws: AddCommandError.passwordGenerationMessage(
        "Password length must be at least the number of enabled character sets."
      )
    ) {
      try command.run()
    }
  }

  @Test("run maps stdin EOF to a user-friendly input error")
  func runMapsStdinEOFToInputError() {
    var command = AddCommand(
      service: "example.com",
      account: "bot@example.com",
      label: nil,
      stdin: true,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { _, _, _, _, _ in
        Issue.record("Keychain should not be called when stdin has no data.")
      },
      generatePassword: { _ in
        ""
      },
      readStdinLine: {
        nil
      },
      promptPassword: {
        ""
      },
      output: { _ in
      }
    )

    #expect(throws: AddCommandError.passwordInputFailed) {
      try command.run()
    }
  }
}

@Suite(.serialized)
struct AddCommandIntegrationTests {
  @Test("run stores an item in keychain and prints success message")
  func runStoresItemAndPrintsSuccessMessage() throws {
    let keychain = AddCommandTestKeychain()
    let manager = KeychainManager(
      copyMatching: keychain.copyMatching,
      add: keychain.add
    )

    let service = "applpass.add.command.integration.\(UUID().uuidString)"
    let account = "bot-\(UUID().uuidString)@example.com"
    let password = "secret-\(UUID().uuidString)"
    let outputMessage = SendableBox("")

    var command = AddCommand(
      service: service,
      account: account,
      label: "Add Command Integration",
      stdin: false,
      generate: false,
      sync: false,
      length: 32,
      addPassword: { service, account, password, label, sync in
        try manager.addPassword(
          service: service,
          account: account,
          password: password,
          label: label,
          sync: sync
        )
      },
      generatePassword: { _ in
        Issue.record("Generation should not be used in this integration test.")
        return ""
      },
      readStdinLine: {
        Issue.record("stdin should not be used in this integration test.")
        return nil
      },
      promptPassword: {
        password
      },
      output: { message in
        outputMessage.value = message
      }
    )

    try command.run()

    #expect(
      outputMessage.value
        == "Added password for service '\(service)' and account '\(account)'."
    )

    let query = KeychainQuery(
      service: service,
      account: account,
      domain: nil,
      includeShared: false,
      itemClass: .genericPassword,
      limit: 1
    )
    let item = try manager.getPassword(for: query)

    #expect(item.service == service)
    #expect(item.account == account)
    #expect(item.password == password)
    #expect(item.label == "Add Command Integration")
    #expect(item.itemClass == .genericPassword)
  }
}

private final class SendableBox<Value>: @unchecked Sendable {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}

private final class AddCommandTestKeychain: @unchecked Sendable {
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
      kSecAttrLabel as String: dictionary[kSecAttrLabel as String] as? String as Any,
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
}
